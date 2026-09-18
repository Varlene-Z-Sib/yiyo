from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth as firebase_auth
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.models.report_model import VibeReportCreate
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
    location_key_for,
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

REPORT_COOLDOWN_SECONDS = 300  # 5 minutes per user per venue
VENUE_CACHE_TTL_SECONDS = 7 * 24 * 60 * 60  # 7 days


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

    token = authorization.split("Bearer ", 1)[1].strip()

    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing token",
        )

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded

    except Exception as e:
        print(f"[ERROR] Token verification failed: {e}")

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
    """
    Persist only canonical venue data.

    Request-specific values such as distance, relevance score,
    location cache keys and YIYO state are deliberately excluded
    by VenueRecord.
    """

    saved = 0
    now = datetime.now(timezone.utc)

    for venue in venues:
        try:
            place_id = venue.get("place_id")

            if not place_id:
                continue

            record_data = {
                **venue,
                "google_last_refreshed_at": now.isoformat(),
                "google_last_refreshed_at_unix": int(
                    now.timestamp()
                ),
            }

            record = VenueRecord(**record_data)

            db.collection(
                VENUES_COLLECTION
            ).document(
                place_id
            ).set(
                record.model_dump(),
                merge=False,
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
    """
    Store which venue IDs belong to a discovery area and when
    Google Places last refreshed that area.
    """

    location_key = location_key_for(lat, lng)
    now = datetime.now(timezone.utc)

    venue_ids: list[str] = []

    for venue in venues:
        venue_id = (
            venue.get("place_id")
            or venue.get("id")
        )

        if venue_id and venue_id not in venue_ids:
            venue_ids.append(venue_id)

    db.collection(
        VENUE_AREA_CACHE_COLLECTION
    ).document(
        location_key
    ).set(
        {
            "location_key": location_key,
            "venue_ids": venue_ids,
            "last_refreshed_at_unix": int(
                now.timestamp()
            ),
            "last_refreshed_at": now.isoformat(),
        },
        merge=True,
    )


def load_cached_area_venues(
    lat: float,
    lng: float,
) -> Optional[list[dict]]:
    """
    Load a valid area cache.

    None means:
        no usable cache exists and Google may be called.

    [] means:
        a valid cache exists but Google found no venues, so do
        not immediately call Google again.
    """

    location_key = location_key_for(lat, lng)

    area_snapshot = (
        db.collection(
            VENUE_AREA_CACHE_COLLECTION
        )
        .document(location_key)
        .get()
    )

    if not area_snapshot.exists:
        return None

    area_data = area_snapshot.to_dict() or {}

    now_unix = int(
        datetime.now(timezone.utc).timestamp()
    )

    if not is_cache_fresh(
        area_data.get("last_refreshed_at_unix"),
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

    docs = db.get_all(venue_refs)

    venues = [
        doc.to_dict() | {"id": doc.id}
        for doc in docs
        if doc.exists
    ]

    # Distance and relevance are specific to this request,
    # not canonical venue properties.
    venues = [
        apply_discovery_context(
            venue,
            lat,
            lng,
        )
        for venue in venues
    ]

    # Community state is also dynamic.
    for venue in venues:
        venue["yiyo_badge"] = (
            get_venue_yiyo_badge(
                venue.get("place_id")
                or venue.get("id")
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
        return "firestore_cache", cached

    venues = fetch_nightlife_places(
        lat,
        lng,
    )

    save_venues_to_firestore(venues)

    save_area_cache(
        lat,
        lng,
        venues,
    )

    for venue in venues:
        venue["yiyo_badge"] = (
            get_venue_yiyo_badge(
                venue.get("place_id")
            )
        )

    return "google_places", venues


# ---------------------------------------------------------------------------
# Search helpers
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
# YIYO community state
# ---------------------------------------------------------------------------

def get_venue_yiyo_badge(
    venue_id: Optional[str],
) -> str:
    if not venue_id:
        return "MID"

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

    reports = [
        doc.to_dict()
        for doc in docs
    ]

    reports.sort(
        key=lambda report: int(
            report.get(
                "created_at_unix",
                0,
            )
        ),
        reverse=True,
    )

    return get_yiyo_badge_from_reports(
        reports[:12]
    )


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

    user_data = snapshot.to_dict() or {}

    current_count = (
        int(
            user_data.get(
                "report_count",
                0,
            )
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
            "report_count": current_count,
            "contributor_level": (
                contributor_level
            ),
            "updated_at": (
                datetime.now(
                    timezone.utc
                ).isoformat()
            ),
        },
        merge=True,
    )


def check_report_cooldown(
    uid: str,
    venue_id: str,
):
    docs = (
        db.collection(REPORTS_COLLECTION)
        .where(
            filter=FieldFilter(
                "uid",
                "==",
                uid,
            )
        )
        .where(
            filter=FieldFilter(
                "venue_id",
                "==",
                venue_id,
            )
        )
        .order_by(
            "created_at_unix",
            direction="DESCENDING",
        )
        .limit(1)
        .stream()
    )

    latest_doc = next(docs, None)

    if latest_doc is None:
        return

    latest = latest_doc.to_dict() or {}

    latest_unix = int(
        latest.get(
            "created_at_unix",
            0,
        )
        or 0
    )

    if not latest_unix:
        return

    now_unix = int(
        datetime.now(
            timezone.utc
        ).timestamp()
    )

    elapsed = now_unix - latest_unix

    if elapsed < REPORT_COOLDOWN_SECONDS:
        remaining = (
            REPORT_COOLDOWN_SECONDS
            - elapsed
        )

        raise HTTPException(
            status_code=429,
            detail=(
                "Please wait "
                f"{remaining} seconds "
                "before reporting this venue again"
            ),
        )


# ---------------------------------------------------------------------------
# Basic health route
# ---------------------------------------------------------------------------

@app.get("/")
def root():
    return {
        "message": "YIYO Backend Running 🚀"
    }


# ---------------------------------------------------------------------------
# Venue routes
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

    yiyo_venues = []

    for venue in venues:
        badge = get_venue_yiyo_badge(
            venue.get("place_id")
            or venue.get("id")
        )

        venue["yiyo_badge"] = badge

        if badge == "YIYO":
            yiyo_venues.append(venue)

    return {
        "count": len(yiyo_venues),
        "venues": yiyo_venues,
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
        match_score = score_cached_match(
            venue,
            query,
        )

        if match_score > 0:
            venue_copy = dict(venue)

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
        best_match = matched_cached[0]

        best_match_id = (
            best_match.get("place_id")
            or best_match.get("id")
        )

        related = [
            venue
            for venue in cached_area_venues
            if (
                venue.get("place_id")
                or venue.get("id")
            )
            != best_match_id
        ]

        return {
            "source": "firestore_search",
            "best_match": best_match,
            "related_venues": related[:12],
            "used_places_call": False,
        }

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

    for venue in search_results:
        venue["yiyo_badge"] = (
            get_venue_yiyo_badge(
                venue.get("place_id")
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

    if enrich_area and best_match:
        enriched = fetch_nightlife_places(
            best_match["lat"],
            best_match["lng"],
        )

        save_venues_to_firestore(
            enriched
        )

        save_area_cache(
            best_match["lat"],
            best_match["lng"],
            enriched,
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
                and place_id not in seen
                and place_id
                != best_match.get(
                    "place_id"
                )
            ):
                item["yiyo_badge"] = (
                    get_venue_yiyo_badge(
                        place_id
                    )
                )

                seen.add(place_id)

                merged_related.append(
                    item
                )

        related_venues = (
            merged_related[:12]
        )

    return {
        "source": "google_text_search",
        "best_match": best_match,
        "related_venues": related_venues,
        "used_places_call": True,
        "enriched_area": (
            enrich_area
            and best_match is not None
        ),
    }

def get_canonical_venue_or_404(
    venue_id: str,
) -> dict:
    snapshot = (
        db.collection(VENUES_COLLECTION)
        .document(venue_id)
        .get()
    )

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Venue not found",
        )

    venue = snapshot.to_dict() or {}

    venue_name = str(
        venue.get("name", "")
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
# Report / contribution routes
# ---------------------------------------------------------------------------

@app.post("/reports")
def create_vibe_report(
    report: VibeReportCreate,
    current_user=Depends(
        get_current_user
    ),
):
    try:
        uid = current_user.get("uid")
        email = current_user.get(
            "email",
            "",
        )
        display_name = current_user.get(
            "name",
            "",
        )

        if not uid:
            raise HTTPException(
                status_code=401,
                detail="Invalid user",
            )

        canonical_venue = get_canonical_venue_or_404(
            report.venue_id
        )

        canonical_venue_name = str(
            canonical_venue["name"]
        ).strip()

        check_report_cooldown(
            uid,
            report.venue_id,
        )

        # The server is authoritative for report time.
        # We deliberately do not trust a client-supplied
        # reported_at value for freshness calculations.
        now = datetime.now(
            timezone.utc
        )

        payload = {
            "venue_id": report.venue_id,
            "venue_name": canonical_venue_name,
            "crowd_level": report.crowd_level,
            "safety_level": report.safety_level,
            "music_type": report.music_type,
            "queue_length": report.queue_length,
            "yiyo_status": report.yiyo_status,
            "parking_availability": (
                report.parking_availability
            ),
            "parking_safety": (
                report.parking_safety
            ),
            "parking_note": (
                report.parking_note
            ),
            "comment": report.comment,
            "reported_at": (
                now.isoformat()
            ),
            "created_at_unix": int(
                now.timestamp()
            ),
            "uid": uid,
            "user_email": email,
            "user_display_name": (
                display_name
            ),
        }

        doc_ref = (
            db.collection(
                REPORTS_COLLECTION
            )
            .document()
        )

        doc_ref.set(payload)

        update_user_report_stats(uid)

        payload["id"] = doc_ref.id

        return {
            "message": (
                "Report saved successfully"
            ),
            "report": payload,
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
            detail="Failed to save report",
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

        reports = [
            doc.to_dict()
            | {"id": doc.id}
            for doc in docs
        ]

        reports.sort(
            key=lambda report: int(
                report.get(
                    "created_at_unix",
                    0,
                )
            ),
            reverse=True,
        )

        yiyo_badge = (
            get_yiyo_badge_from_reports(
                reports[:12]
            )
        )

        # Internal Firestore reports retain account
        # information for ownership/moderation, but those
        # identifiers should not be exposed publicly.
        public_reports = []

        for report in reports[:20]:
            public_report = {
                key: value
                for key, value
                in report.items()
                if key
                not in {
                    "uid",
                    "user_email",
                    "user_display_name",
                }
            }

            public_reports.append(
                public_report
            )

        return {
            "count": len(reports),
            "yiyo_badge": yiyo_badge,
            "reports": public_reports,
        }

    except Exception as e:
        print(
            "[ERROR] Failed to fetch reports "
            f"for venue {venue_id}: {e}"
        )

        raise HTTPException(
            status_code=500,
            detail="Failed to fetch reports",
        )