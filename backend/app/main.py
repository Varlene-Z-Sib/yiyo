from datetime import datetime, timezone
from typing import Optional
from app.services.authorization_service import (
    get_effective_permissions,
    grant_business_membership,
    require_moderator,
    require_super_admin,
    suspend_business_membership,
    get_admin_user_access_by_username,
    search_admin_venues,
    get_profile_access_summary,

)
from app.models.authorization_model import (
    MembershipGrantRequest,
)
from app.services.account_deletion_service import (
    delete_yiyo_account_data,
    require_recent_auth,
)
from app.services.materialized_vibe_service import (
    attach_materialized_community_states,
    safe_rebuild_venue_community_summary,
)
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth as firebase_auth
from google.cloud.firestore_v1.base_query import FieldFilter
from app.services.user_service import (
    get_user_contributions,
    get_user_profile,
    update_user_identity,
)
from app.services.vibe_summary_service import (
    build_current_vibe_summary,
)
from app.models.user_model import (
    UserProfileUpdate,
)
from app.firebase_config import db
from app.models.report_model import (
    ReportFlagCreate,
    VibeReportCreate,
)
from app.services.report_service import (
    enforce_contribution_rate_limits,
    flag_report_for_moderation,
)
from app.models.venue_model import VenueRecord
from app.services.places_service import (
    apply_discovery_context,
    fetch_nightlife_places,
    search_places_by_text,
)
from app.services.yiyo_logic import (
    contributor_level_from_count,
    get_yiyo_badge_from_reports,
    is_cache_fresh,
    is_report_active,
    location_key_for,
)

from app.models.event_model import (
    EventCreate,
    EventUpdate,
)

from app.services.event_service import (
    approve_event,
    cancel_event,
    create_event,
    get_pending_event_approvals,
    get_public_event,
    get_upcoming_events,
    get_user_events,
    reject_event,
    delete_event,
    get_manageable_events,
    update_event,
)

from app.models.event_engagement_model import (
    EventReactionType,
)

from app.services.event_engagement_service import (
    get_event_engagement_state,
    toggle_event_reaction,
)

app = FastAPI(title="YIYO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


VENUES_COLLECTION = "venues_v2"
VENUE_AREA_CACHE_COLLECTION = "venue_area_cache"
REPORTS_COLLECTION = "vibe_reports"
USERS_COLLECTION = "users"

REPORT_COOLDOWN_SECONDS = 300
VENUE_CACHE_TTL_SECONDS = 7 * 24 * 60 * 60


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

def get_current_user(
    authorization: Optional[str] = Header(default=None),
):
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing Authorization header",
        )

    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Invalid Authorization header",
        )

    token = authorization.split(
        "Bearer ",
        1,
    )[1].strip()

    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing token",
        )

    try:
        return firebase_auth.verify_id_token(
            token
        )

    except Exception as e:
        print(
            "[ERROR] Token verification failed: "
            f"{e}"
        )

        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
        )


# ---------------------------------------------------------------------------
# Venue persistence
# ---------------------------------------------------------------------------

def save_venues_to_firestore(
    venues: list[dict],
) -> int:
    saved = 0

    now = datetime.now(
        timezone.utc
    )

    for venue in venues:
        try:
            place_id = venue.get(
                "place_id"
            )

            if not place_id:
                continue

            record_data = {
                **venue,
                "google_last_refreshed_at":
                    now.isoformat(),
                "google_last_refreshed_at_unix":
                    int(now.timestamp()),
            }

            record = VenueRecord(
                **record_data
            )

            (
                db.collection(
                    VENUES_COLLECTION
                )
                .document(place_id)
                .set(
                    record.model_dump(),
                    merge=False,
                )
            )

            saved += 1

        except Exception as e:
            print(
                "[ERROR] Failed to save venue "
                f"{venue.get('name')}: {e}"
            )

    return saved


def save_area_cache(
    lat: float,
    lng: float,
    venues: list[dict],
):
    location_key = location_key_for(
        lat,
        lng,
    )

    now = datetime.now(
        timezone.utc
    )

    venue_ids: list[str] = []

    for venue in venues:
        venue_id = (
            venue.get("place_id")
            or venue.get("id")
        )

        if (
            venue_id
            and venue_id not in venue_ids
        ):
            venue_ids.append(
                venue_id
            )

    (
        db.collection(
            VENUE_AREA_CACHE_COLLECTION
        )
        .document(location_key)
        .set(
            {
                "location_key":
                    location_key,
                "venue_ids":
                    venue_ids,
                "last_refreshed_at_unix":
                    int(now.timestamp()),
                "last_refreshed_at":
                    now.isoformat(),
            },
            merge=True,
        )
    )


def load_cached_area_venues(
    lat: float,
    lng: float,
) -> Optional[list[dict]]:
    location_key = location_key_for(
        lat,
        lng,
    )

    area_snapshot = (
        db.collection(
            VENUE_AREA_CACHE_COLLECTION
        )
        .document(location_key)
        .get()
    )

    if not area_snapshot.exists:
        return None

    area_data = (
        area_snapshot.to_dict()
        or {}
    )

    now_unix = int(
        datetime.now(
            timezone.utc
        ).timestamp()
    )

    if not is_cache_fresh(
        area_data.get(
            "last_refreshed_at_unix"
        ),
        now_unix,
        VENUE_CACHE_TTL_SECONDS,
    ):
        return None

    venue_ids = area_data.get(
        "venue_ids",
        [],
    )

    if not venue_ids:
        return []

    venue_refs = [
        db.collection(
            VENUES_COLLECTION
        ).document(venue_id)
        for venue_id in venue_ids
    ]

    docs = db.get_all(
        venue_refs
    )

    venues = [
        doc.to_dict()
        | {"id": doc.id}
        for doc in docs
        if doc.exists
    ]

    venues = [
        apply_discovery_context(
            venue,
            lat,
            lng,
        )
        for venue in venues
    ]

    venues = (
        attach_materialized_community_states(
            venues
        )
    )

    venues.sort(
        key=lambda venue: (
            -float(
                venue.get(
                    "relevance_score",
                    0,
                )
                or 0
            ),
            float(
                venue.get(
                    "distance_km",
                    999,
                )
                or 999
            ),
            -float(
                venue.get(
                    "rating",
                    0,
                )
                or 0
            ),
        )
    )

    return venues


def get_or_build_area_venues(
    lat: float,
    lng: float,
) -> tuple[str, list[dict]]:
    cached = load_cached_area_venues(
        lat,
        lng,
    )

    if cached is not None:
        return (
            "firestore_cache",
            cached,
        )

    venues = fetch_nightlife_places(
        lat,
        lng,
    )

    save_venues_to_firestore(
        venues
    )

    save_area_cache(
        lat,
        lng,
        venues,
    )

    venues = (
        attach_materialized_community_states(
            venues
        )
    )

    return (
        "google_places",
        venues,
    )


def get_canonical_venue_or_404(
    venue_id: str,
) -> dict:
    snapshot = (
        db.collection(
            VENUES_COLLECTION
        )
        .document(venue_id)
        .get()
    )

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Venue not found",
        )

    venue = (
        snapshot.to_dict()
        or {}
    )

    venue_name = str(
        venue.get(
            "name",
            "",
        )
    ).strip()

    if not venue_name:
        raise HTTPException(
            status_code=500,
            detail="Venue record is invalid",
        )

    return {
        **venue,
        "id": snapshot.id,
    }


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

def score_cached_match(
    venue: dict,
    query: str,
) -> float:
    name = (
        str(
            venue.get(
                "name",
                "",
            )
        )
        .lower()
        .strip()
    )

    q = query.lower().strip()

    if not q:
        return 0

    if name == q:
        return 100

    if q in name:
        return 70

    tokens = [
        token
        for token in q.split()
        if token
    ]

    token_hits = sum(
        1
        for token in tokens
        if token in name
    )

    return token_hits * 12


# ---------------------------------------------------------------------------
# Community state / moderation
# ---------------------------------------------------------------------------

def update_user_report_stats(
    uid: str,
):
    user_ref = (
        db.collection(
            USERS_COLLECTION
        )
        .document(uid)
    )

    snapshot = user_ref.get()

    if not snapshot.exists:
        return

    user_data = (
        snapshot.to_dict()
        or {}
    )

    current_count = (
        int(
            user_data.get(
                "report_count",
                0,
            )
            or 0
        )
        + 1
    )

    contributor_level = (
        contributor_level_from_count(
            current_count
        )
    )

    user_ref.set(
        {
            "report_count":
                current_count,
            "contributor_level":
                contributor_level,
            "updated_at":
                datetime.now(
                    timezone.utc
                ).isoformat(),
        },
        merge=True,
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/")
def root():
    return {
        "message":
            "YIYO Backend Running 🚀"
    }


# ---------------------------------------------------------------------------
# Venues
# ---------------------------------------------------------------------------

@app.get("/venues")
def get_venues(
    lat: float = Query(...),
    lng: float = Query(...),
):
    source, venues = (
        get_or_build_area_venues(
            lat,
            lng,
        )
    )

    return {
        "source": source,
        "count": len(venues),
        "venues": venues,
    }


@app.get("/venues/yiyo")
def get_yiyo_venues(
    lat: float = Query(...),
    lng: float = Query(...),
):
    _, venues = (
        get_or_build_area_venues(
            lat,
            lng,
        )
    )

    yiyo_venues = [
        venue
        for venue in venues
        if (
            venue.get(
                "yiyo_badge"
            )
            == "YIYO"
        )
    ]

    return {
        "count":
            len(yiyo_venues),

        "venues":
            yiyo_venues,
    }


@app.get("/search")
def search_venues(
    q: str = Query(
        ...,
        min_length=1,
    ),
    lat: float = Query(...),
    lng: float = Query(...),
    enrich_area: bool = Query(False),
):
    query = q.strip()

    if not query:
        raise HTTPException(
            status_code=400,
            detail="Query is required",
        )

    cached_area_venues = (
        load_cached_area_venues(
            lat,
            lng,
        )
        or []
    )

    matched_cached = []

    for venue in cached_area_venues:
        match_score = (
            score_cached_match(
                venue,
                query,
            )
        )

        if match_score > 0:
            venue_copy = dict(
                venue
            )

            venue_copy[
                "search_match_score"
            ] = match_score

            matched_cached.append(
                venue_copy
            )

    matched_cached.sort(
        key=lambda venue: (
            -float(
                venue.get(
                    "search_match_score",
                    0,
                )
                or 0
            ),
            -float(
                venue.get(
                    "relevance_score",
                    0,
                )
                or 0
            ),
            float(
                venue.get(
                    "distance_km",
                    999,
                )
                or 999
            ),
        )
    )

    if matched_cached:
        best_match = (
            matched_cached[0]
        )

        best_match_id = (
            best_match.get(
                "place_id"
            )
            or best_match.get(
                "id"
            )
        )

        related = [
            venue
            for venue
            in cached_area_venues
            if (
                venue.get(
                    "place_id"
                )
                or venue.get(
                    "id"
                )
            )
            != best_match_id
        ]

        return {
            "source":
                "firestore_search",
            "best_match":
                best_match,
            "related_venues":
                related[:12],
            "used_places_call":
                False,
        }

    # The venue may already exist in YIYO's
    # canonical registry even when it is not
    # part of this location's current area cache.
    # Check venues_v2 before paying for another
    # Google Places text search.
    if len(query) >= 2:
        registry_matches = (
            search_admin_venues(
                query=query,
                limit=13,
            )
        )

        if registry_matches:
            venue_refs = [
                db.collection(
                    VENUES_COLLECTION
                ).document(
                    item["id"]
                )
                for item
                in registry_matches
            ]

            docs = db.get_all(
                venue_refs
            )

            registry_by_id = {
                doc.id: (
                    doc.to_dict()
                    or {}
                )
                | {
                    "id": doc.id,
                }
                for doc in docs
                if doc.exists
            }

            registry_venues = []

            # Preserve the ranking returned by
            # search_admin_venues().
            for match in registry_matches:
                venue = (
                    registry_by_id.get(
                        match["id"]
                    )
                )

                if venue is None:
                    continue

                try:
                    venue = (
                        apply_discovery_context(
                            venue,
                            lat,
                            lng,
                        )
                    )

                except (
                    KeyError,
                    TypeError,
                    ValueError,
                ) as e:
                    print(
                        "[WARN] Invalid registry "
                        "venue during search "
                        f"{match['id']}: {e}"
                    )
                    continue

                registry_venues.append(
                    venue
                )

            registry_venues = (
                attach_materialized_community_states(
                    registry_venues
                )
            )

            if registry_venues:
                return {
                    "source":
                        "firestore_registry_search",
                    "best_match":
                        registry_venues[0],
                    "related_venues":
                        registry_venues[1:13],
                    "used_places_call":
                        False,
                    "enriched_area":
                        False,
                }

    # Google Places is the final fallback only
    # when YIYO does not already know the venue.
    search_results = (
        search_places_by_text(
            query,
            lat,
            lng,
        )
    )

    save_venues_to_firestore(
        search_results
    )

    search_results = (
        attach_materialized_community_states(
            search_results
        )
    )

    best_match = (
        search_results[0]
        if search_results
        else None
    )

    related_venues = (
        search_results[1:13]
        if len(search_results) > 1
        else []
    )

    if (
        enrich_area
        and best_match
    ):
        enriched = (
            fetch_nightlife_places(
                best_match["lat"],
                best_match["lng"],
            )
        )

        save_venues_to_firestore(
            enriched
        )

        save_area_cache(
            best_match["lat"],
            best_match["lng"],
            enriched,
        )

        enriched = (
            attach_materialized_community_states(
                enriched
            )
        )

        seen: set[str] = set()
        merged_related = []

        for item in (
            related_venues
            + enriched
        ):
            place_id = item.get(
                "place_id"
            )

            if (
                place_id
                and place_id
                not in seen
                and place_id
                != best_match.get(
                    "place_id"
                )
            ):
                seen.add(
                    place_id
                )

                merged_related.append(
                    item
                )

        related_venues = (
            merged_related[:12]
        )

    return {
        "source":
            "google_text_search",
        "best_match":
            best_match,
        "related_venues":
            related_venues,
        "used_places_call":
            True,
        "enriched_area":
            (
                enrich_area
                and best_match is not None
            ),
    }


# ---------------------------------------------------------------------------
# Contributions
# ---------------------------------------------------------------------------

@app.post("/reports")
def create_vibe_report(
    report: VibeReportCreate,
    current_user=Depends(
        get_current_user
    ),
):
    try:
        uid = current_user.get(
            "uid"
        )

        email = current_user.get(
            "email",
            "",
        )

        display_name = (
            current_user.get(
                "name",
                "",
            )
        )

        if not uid:
            raise HTTPException(
                status_code=401,
                detail="Invalid user",
            )

        canonical_venue = (
            get_canonical_venue_or_404(
                report.venue_id
            )
        )

        canonical_venue_name = str(
            canonical_venue["name"]
        ).strip()

        enforce_contribution_rate_limits(
            uid,
            report.venue_id,
        )

        now = datetime.now(
            timezone.utc
        )

        # ------------------------------------------------------------------
        # Required / server-owned report fields
        # ------------------------------------------------------------------

        payload = {
            "venue_id":
                report.venue_id,

            "venue_name":
                canonical_venue_name,

            "crowd_level":
                report.crowd_level,

            "yiyo_status":
                report.yiyo_status,

            "reported_at":
                now.isoformat(),

            "created_at_unix":
                int(
                    now.timestamp()
                ),

            "uid":
                uid,

            "user_email":
                email,

            "user_display_name":
                display_name,

            # Moderation state is owned by the server.
            "status":
                "active",
        }

        # ------------------------------------------------------------------
        # Optional Quick Vibe detail fields
        #
        # Only store these when the user actually supplied them.
        # This prevents a quick contribution from inventing/recording
        # unknown safety, music, queue or parking information.
        # ------------------------------------------------------------------

        if report.safety_level is not None:
            payload[
                "safety_level"
            ] = report.safety_level

        if report.music_type is not None:
            payload[
                "music_type"
            ] = report.music_type

        if report.queue_length is not None:
            payload[
                "queue_length"
            ] = report.queue_length

        if (
            report.parking_availability
            is not None
        ):
            payload[
                "parking_availability"
            ] = (
                report.parking_availability
            )

        if report.parking_safety is not None:
            payload[
                "parking_safety"
            ] = report.parking_safety

        if report.parking_note:
            payload[
                "parking_note"
            ] = report.parking_note

        if report.comment:
            payload[
                "comment"
            ] = report.comment

        # ------------------------------------------------------------------
        # Persist source report
        # ------------------------------------------------------------------

        doc_ref = (
            db.collection(
                REPORTS_COLLECTION
            )
            .document()
        )

        doc_ref.set(
            payload
        )

        update_user_report_stats(
            uid
        )

        # vibe_reports remains the source of truth.
        #
        # Rebuilding the discovery cache is best-effort:
        # a cache/index failure must never turn a valid
        # contribution into a failed submission.
        safe_rebuild_venue_community_summary(
            report.venue_id
        )

        payload["id"] = (
            doc_ref.id
        )

        return {
            "message":
                "Report saved successfully",

            "report":
                payload,
        }

    except HTTPException:
        raise

    except Exception as e:
        print(
            "[ERROR] Failed to save "
            f"report: {e}"
        )

        raise HTTPException(
            status_code=500,
            detail=
                "Failed to save report",
        )


@app.post("/reports/{report_id}/flag")
def flag_report(
    report_id: str,
    flag: ReportFlagCreate,
    current_user=Depends(
        get_current_user
    ),
):
    uid = current_user.get(
        "uid"
    )

    if not uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    return flag_report_for_moderation(
        report_id=report_id,
        uid=uid,
        reason=flag.reason,
        details=flag.details,
    )


@app.get("/reports/{venue_id}")
def get_reports_for_venue(
    venue_id: str,
):
    try:
        docs = (
            db.collection(
                REPORTS_COLLECTION
            )
            .where(
                filter=FieldFilter(
                    "venue_id",
                    "==",
                    venue_id,
                )
            )
            .stream()
        )

        all_reports = [
            doc.to_dict()
            | {"id": doc.id}
            for doc in docs
        ]

        # Legacy reports without a status are treated as active.
        # Flagged and removed reports stay in Firestore but are not
        # returned publicly.
        active_reports = [
            report
            for report in all_reports
            if is_report_active(
                report
            )
        ]

        active_reports.sort(
            key=lambda report: int(
                report.get(
                    "created_at_unix",
                    0,
                )
                or 0
            ),
            reverse=True,
        )

        yiyo_badge = (
            get_yiyo_badge_from_reports(
                active_reports[:12]
            )
        )

        summary = (
            build_current_vibe_summary(
                active_reports
            )
        )

        public_reports = []

        for report in active_reports[:20]:
            public_report = {
                key: value
                for key, value
                in report.items()
                if key
                not in {
                    "uid",
                    "user_email",
                    "user_display_name",
                    "status",
                }
            }

            public_reports.append(
                public_report
            )

        return {
            "count":
                len(active_reports),

            "yiyo_badge":
                yiyo_badge,

            "summary":
                summary.model_dump(),

            "reports":
                public_reports,
        }

    except Exception as e:
        print(
            "[ERROR] Failed to fetch reports "
            f"for venue {venue_id}: {e}"
        )

        raise HTTPException(
            status_code=500,
            detail=
                "Failed to fetch reports",
        )


# ---------------------------------------------------------------------------
# Current user / profile
# ---------------------------------------------------------------------------

@app.get("/me")
def get_my_profile(
    current_user=Depends(
        get_current_user
    ),
):
    uid = current_user.get(
        "uid"
    )

    if not uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    profile = get_user_profile(
        uid=uid,

        token_email=str(
            current_user.get(
                "email",
                "",
            )
            or ""
        ),

        token_display_name=str(
            current_user.get(
                "name",
                "",
            )
            or ""
        ),

        token_provider=str(
            (
                current_user.get(
                    "firebase",
                    {},
                )
                or {}
            ).get(
                "sign_in_provider",
                "",
            )
            or ""
        ),
    )

    return profile.model_dump()


@app.delete("/me")
def delete_my_account(
    current_user=Depends(
        get_current_user
    ),
):
    uid = require_recent_auth(
        current_user
    )

    cleanup = (
        delete_yiyo_account_data(
            uid
        )
    )

    try:
        # Firebase Auth is deliberately
        # deleted LAST.
        firebase_auth.delete_user(
            uid
        )

    except Exception as e:
        print(
            "[ERROR] YIYO account data "
            "was cleaned but Firebase Auth "
            "deletion failed for "
            f"{uid}: {e}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Your account data was "
                "prepared for deletion, but "
                "authentication deletion "
                "could not finish. "
                "Please try again."
            ),
        )

    print(
        "[INFO] Deleted YIYO account "
        f"{uid}: {cleanup}"
    )

    return {
        "deleted":
            True,
    }


@app.patch("/me")
def update_my_profile(
    request: UserProfileUpdate,

    current_user=Depends(
        get_current_user
    ),
):
    uid = current_user.get(
        "uid"
    )

    if not uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    profile = update_user_identity(
        uid=
            uid,

        username=
            request.username,

        full_name=
            request.full_name,

        token_email=
            str(
                current_user.get(
                    "email",
                    "",
                )
                or ""
            ),
    )

    try:
        firebase_auth.update_user(
            uid,
            display_name=
                profile.username,
        )

    except Exception as e:
        # Firestore remains the YIYO
        # source of truth for profile identity.
        print(
            "[WARN] Failed to update "
            "Firebase display name for "
            f"{uid}: {e}"
        )

    return profile.model_dump()


@app.get("/me/event-approvals")
def get_my_event_approvals(
    limit: int = Query(
        50,
        ge=1,
        le=100,
    ),

    current_user=Depends(
        get_current_user
    ),
):
    events = (
        get_pending_event_approvals(
            current_user=
                current_user,
            limit=
                limit,
        )
    )

    return {
        "count":
            len(events),

        "events": [
            event.model_dump(
                mode="json"
            )
            for event in events
        ],
    }


@app.get("/me/reports")
def get_my_reports(
    limit: int = Query(
        30,
        ge=1,
        le=50,
    ),

    current_user=Depends(
        get_current_user
    ),
):
    uid = current_user.get(
        "uid"
    )

    if not uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    reports = (
        get_user_contributions(
            uid=uid,
            limit=limit,
        )
    )

    return {
        "count": len(reports),

        "reports": [
            report.model_dump()
            for report in reports
        ],
    }


@app.get("/me/events")
def get_my_events(
    limit: int = Query(
        50,
        ge=1,
        le=100,
    ),

    current_user=Depends(
        get_current_user
    ),
):
    events = get_user_events(
        current_user=current_user,
        limit=limit,
    )

    return {
        "count":
            len(events),

        "events": [
            event.model_dump(
                mode="json"
            )
            for event in events
        ],
    }


@app.get("/me/permissions")
def get_my_permissions(
    current_user=Depends(
        get_current_user
    ),
):
    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    return (
        permissions.model_dump(
            mode="json"
        )
    )


@app.get("/moderation/access-check")
def moderation_access_check(
    current_user=Depends(
        get_current_user
    ),
):
    auth = require_moderator(
        current_user
    )

    return {
        "ok": True,
        "uid": auth.uid,
        "app_role":
            auth.app_role.value,
    }


@app.get(
    "/admin/users/by-username/"
    "{username}"
)
def admin_get_user_by_username(
    username: str,

    current_user=Depends(
        get_current_user
    ),
):
    require_super_admin(
        current_user
    )

    return (
        get_admin_user_access_by_username(
            username
        )
    )


@app.get("/admin/access-check")
def admin_access_check(
    current_user=Depends(
        get_current_user
    ),
):
    auth = require_super_admin(
        current_user
    )

    return {
        "ok": True,
        "uid": auth.uid,
        "app_role":
            auth.app_role.value,
    }


@app.post("/admin/memberships")
def admin_grant_membership(
    request: MembershipGrantRequest,

    current_user=Depends(
        get_current_user
    ),
):
    admin = require_super_admin(
        current_user
    )

    membership = (
        grant_business_membership(
            user_id=
                request.user_id,

            role=
                request.role,

            venue_id=
                request.venue_id,

            granted_by_uid=
                admin.uid,
        )
    )

    return (
        membership.model_dump(
            mode="json"
        )
    )

@app.post(
    "/admin/memberships/"
    "{membership_id}/suspend"
)
def admin_suspend_membership(
    membership_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    admin = require_super_admin(
        current_user
    )

    membership = (
        suspend_business_membership(
            membership_id,
            suspended_by_uid=
                admin.uid,
        )
    )

    return (
        membership.model_dump(
            mode="json"
        )
    )


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

@app.get("/events")
def list_upcoming_events(
    limit: int = Query(
        30,
        ge=1,
        le=100,
    ),
):
    events = (
        get_upcoming_events(
            limit=limit
        )
    )

    return {
        "count":
            len(events),

        "events": [
            event.model_dump(
                mode="json"
            )
            for event in events
        ],
    }


@app.post(
    "/events/{event_id}/cancel"
)
def cancel_yiyo_event(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    event = cancel_event(
        event_id=event_id,
        current_user=
            current_user,
    )

    return event.model_dump(
        mode="json"
    )


@app.get("/events/{event_id}")
def get_event(
    event_id: str,
):
    event = (
        get_public_event(
            event_id
        )
    )

    return event.model_dump(
        mode="json"
    )


@app.post(
    "/events",
    status_code=201,
)
def create_yiyo_event(
    request: EventCreate,

    current_user=Depends(
        get_current_user
    ),
):
    canonical_venue = (
        get_canonical_venue_or_404(
            request.venue_id
        )
    )

    event = create_event(
        request=request,
        current_user=current_user,
        canonical_venue=
            canonical_venue,
    )

    return event.model_dump(
        mode="json"
    )


@app.post(
    "/events/{event_id}/reject"
)
def reject_yiyo_event(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    event = reject_event(
        event_id=
            event_id,

        current_user=
            current_user,
    )

    return event.model_dump(
        mode="json"
    )


@app.post(
    "/events/{event_id}/approve"
)
def approve_yiyo_event(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    event = approve_event(
        event_id=event_id,
        current_user=
            current_user,
    )

    return event.model_dump(
        mode="json"
    )


@app.post(
    "/events/{event_id}/hype"
)
def toggle_event_hype(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    result = (
        toggle_event_reaction(
            event_id=
                event_id,

            current_user=
                current_user,

            reaction=
                EventReactionType
                .HYPE,
        )
    )

    return result.model_dump(
        mode="json"
    )


@app.post(
    "/events/{event_id}/going"
)
def toggle_event_going(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    result = (
        toggle_event_reaction(
            event_id=
                event_id,

            current_user=
                current_user,

            reaction=
                EventReactionType
                .GOING,
        )
    )

    return result.model_dump(
        mode="json"
    )


@app.get(
    "/events/{event_id}/engagement"
)
def get_my_event_engagement(
    event_id: str,

    current_user=Depends(
        get_current_user
    ),
):
    state = (
        get_event_engagement_state(
            event_id=
                event_id,

            current_user=
                current_user,
        )
    )

    return state.model_dump(
        mode="json"
    )


@app.patch(
    "/events/{event_id}"
)
def edit_event(
    event_id: str,
    request: EventUpdate,
    current_user=Depends(
        get_current_user
    ),
):
    event = update_event(
        event_id=
            event_id,

        request=
            request,

        current_user=
            current_user,
    )

    return event.model_dump(
        mode="json"
    )


@app.delete(
    "/events/{event_id}"
)
def remove_event(
    event_id: str,
    current_user=Depends(
        get_current_user
    ),
):
    return delete_event(
        event_id=
            event_id,

        current_user=
            current_user,
    )


@app.get(
    "/me/manageable-events"
)
def my_manageable_events(
    limit: int = 100,
    current_user=Depends(
        get_current_user
    ),
):
    events = (
        get_manageable_events(
            current_user=
                current_user,

            limit=
                limit,
        )
    )

    return {
        "count":
            len(
                events
            ),

        "events": [
            event.model_dump(
                mode="json"
            )
            for event
            in events
        ],
    }


@app.get(
    "/admin/venues/search"
)
def admin_search_venues(
    q: str,
    limit: int = 20,

    current_user=Depends(
        get_current_user
    ),
):
    require_super_admin(
        current_user
    )

    venues = (
        search_admin_venues(
            query=q,
            limit=limit,
        )
    )

    return {
        "count":
            len(venues),

        "venues":
            venues,
    }


@app.get(
    "/venues/registry-search"
)
def search_venue_registry(
    q: str,
    limit: int = 20,

    current_user=Depends(
        get_current_user
    ),
):
    if limit < 1 or limit > 50:
        raise HTTPException(
            status_code=400,
            detail="Invalid venue search limit",
        )

    # Authenticated YIYO users may search
    # venues already known to YIYO.
    #
    # This searches venues_v2 only and does
    # not call Google Places.
    venues = (
        search_admin_venues(
            query=q,
            limit=limit,
        )
    )

    return {
        "count":
            len(venues),

        "venues":
            venues,
    }


@app.get(
    "/me/access-summary"
)
def get_my_access_summary(
    current_user=Depends(
        get_current_user
    ),
):
    return get_profile_access_summary(
        current_user
    )