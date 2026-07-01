from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, Query, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google.cloud.firestore_v1.base_query import FieldFilter
from firebase_admin import auth as firebase_auth

from app.firebase_config import db
from app.services.places_service import fetch_nightlife_places, search_places_by_text

app = FastAPI(title="YIYO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

VENUES_COLLECTION = "venues_v2"
REPORTS_COLLECTION = "vibe_reports"
USERS_COLLECTION = "users"
REPORT_COOLDOWN_SECONDS = 300  # 5 min per user per venue


class VibeReportCreate(BaseModel):
    venue_id: str = Field(..., min_length=1)
    venue_name: str = Field(..., min_length=1)
    crowd_level: str = Field(..., min_length=1)
    safety_level: str = Field(..., min_length=1)
    music_type: str = Field(..., min_length=1)
    queue_length: str = Field(..., min_length=1)
    yiyo_status: str = Field(..., min_length=1)

    parking_availability: str = Field(..., min_length=1)
    parking_safety: str = Field(..., min_length=1)
    parking_note: Optional[str] = ""

    comment: Optional[str] = ""
    reported_at: Optional[str] = None


def location_key_for(lat: float, lng: float) -> str:
    return f"{round(lat, 2)}_{round(lng, 2)}"


def contributor_level_from_count(report_count: int) -> str:
    if report_count >= 50:
        return "Legend"
    if report_count >= 20:
        return "Scout"
    if report_count >= 5:
        return "Active"
    return "Rookie"


def get_current_user(authorization: Optional[str] = Header(default=None)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")

    token = authorization.split("Bearer ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded
    except Exception as e:
        print(f"[ERROR] Token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def save_venues_to_firestore(venues: list[dict]):
    saved = 0
    for venue in venues:
        try:
            place_id = venue.get("place_id")
            if not place_id:
                continue

            venue["location_key"] = location_key_for(venue["lat"], venue["lng"])
            if "yiyo_badge" not in venue:
                venue["yiyo_badge"] = get_venue_yiyo_badge(place_id)

            db.collection(VENUES_COLLECTION).document(place_id).set(venue, merge=True)
            saved += 1
        except Exception as e:
            print(f"[ERROR] Failed to save venue {venue.get('name')}: {e}")
    return saved


def load_cached_area_venues(lat: float, lng: float) -> list[dict]:
    location_key = location_key_for(lat, lng)

    docs = (
        db.collection(VENUES_COLLECTION)
        .where(filter=FieldFilter("location_key", "==", location_key))
        .stream()
    )

    venues = [doc.to_dict() | {"id": doc.id} for doc in docs]

    for venue in venues:
        venue["yiyo_badge"] = get_venue_yiyo_badge(
            venue.get("place_id") or venue.get("id")
        )

    venues.sort(
        key=lambda v: (
            -(float(v.get("relevance_score", 0) or 0)),
            float(v.get("distance_km", 999) or 999),
            -(float(v.get("rating", 0) or 0)),
        )
    )

    return venues


def get_or_build_area_venues(lat: float, lng: float) -> tuple[str, list[dict]]:
    cached = load_cached_area_venues(lat, lng)
    if cached:
        return "firestore_cache", cached

    venues = fetch_nightlife_places(lat, lng)
    save_venues_to_firestore(venues)

    for venue in venues:
        venue["yiyo_badge"] = get_venue_yiyo_badge(venue.get("place_id"))

    return "google_places", venues


def score_cached_match(venue: dict, query: str) -> float:
    name = str(venue.get("name", "")).lower().strip()
    q = query.lower().strip()
    if not q:
        return 0

    if name == q:
        return 100
    if q in name:
        return 70

    tokens = [t for t in q.split() if t]
    token_hits = sum(1 for t in tokens if t in name)
    return token_hits * 12


def get_venue_yiyo_badge(venue_id: Optional[str]) -> str:
    if not venue_id:
        return "MID"

    docs = (
        db.collection(REPORTS_COLLECTION)
        .where(filter=FieldFilter("venue_id", "==", venue_id))
        .stream()
    )

    reports = [doc.to_dict() for doc in docs]
    reports.sort(
        key=lambda r: int(r.get("created_at_unix", 0)),
        reverse=True,
    )

    return get_yiyo_badge_from_reports(reports[:12])


def get_yiyo_badge_from_reports(reports: list[dict]) -> str:
    if not reports:
        return "MID"

    total_score = 0.0
    now = datetime.now(timezone.utc)

    for report in reports:
        report_score = 0.0

        yiyo_status = str(report.get("yiyo_status", "")).strip().lower()
        if yiyo_status == "yes definitely":
            report_score += 3
        elif yiyo_status == "kind of":
            report_score += 1
        elif yiyo_status == "no":
            report_score -= 3

        crowd_level = str(report.get("crowd_level", "")).strip().lower()
        if crowd_level == "packed":
            report_score += 2
        elif crowd_level == "busy":
            report_score += 1
        elif crowd_level == "chill":
            report_score += 0
        elif crowd_level == "dead":
            report_score -= 2

        safety_level = str(report.get("safety_level", "")).strip().lower()
        if safety_level == "safe":
            report_score += 2
        elif safety_level == "okay":
            report_score += 0
        elif safety_level == "sketchy":
            report_score -= 2
        elif safety_level == "unsafe":
            report_score -= 4

        created_at_unix = report.get("created_at_unix", 0)
        age_hours = 999.0

        if created_at_unix:
            report_time = datetime.fromtimestamp(created_at_unix, tz=timezone.utc)
            age_hours = (now - report_time).total_seconds() / 3600

        if age_hours <= 3:
            weight = 1.0
        elif age_hours <= 12:
            weight = 0.7
        else:
            weight = 0.4

        total_score += report_score * weight

    if total_score >= 4:
        return "YIYO"
    elif total_score <= -2:
        return "NOT YIYO"
    else:
        return "MID"


def update_user_report_stats(uid: str):
    user_ref = db.collection(USERS_COLLECTION).document(uid)
    snapshot = user_ref.get()

    if not snapshot.exists:
        return

    user_data = snapshot.to_dict() or {}
    current_count = int(user_data.get("report_count", 0)) + 1
    contributor_level = contributor_level_from_count(current_count)

    user_ref.set(
        {
            "report_count": current_count,
            "contributor_level": contributor_level,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        },
        merge=True,
    )


def check_report_cooldown(uid: str, venue_id: str):
    docs = (
        db.collection(REPORTS_COLLECTION)
        .where(filter=FieldFilter("uid", "==", uid))
        .where(filter=FieldFilter("venue_id", "==", venue_id))
        .stream()
    )

    reports = [doc.to_dict() for doc in docs]
    if not reports:
        return

    reports.sort(
        key=lambda r: int(r.get("created_at_unix", 0)),
        reverse=True,
    )

    latest = reports[0]
    latest_unix = int(latest.get("created_at_unix", 0))
    now_unix = int(datetime.now(timezone.utc).timestamp())

    if latest_unix and (now_unix - latest_unix) < REPORT_COOLDOWN_SECONDS:
        remaining = REPORT_COOLDOWN_SECONDS - (now_unix - latest_unix)
        raise HTTPException(
            status_code=429,
            detail=f"Please wait {remaining} seconds before reporting this venue again",
        )


@app.get("/")
def root():
    return {"message": "YIYO Backend Running 🚀"}


@app.get("/venues")
def get_venues(
    lat: float = Query(...),
    lng: float = Query(...),
):
    source, venues = get_or_build_area_venues(lat, lng)
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
    _, venues = get_or_build_area_venues(lat, lng)

    yiyo_venues = []
    for venue in venues:
        badge = get_venue_yiyo_badge(venue.get("place_id") or venue.get("id"))
        venue["yiyo_badge"] = badge
        if badge == "YIYO":
            yiyo_venues.append(venue)

    return {
        "count": len(yiyo_venues),
        "venues": yiyo_venues,
    }


@app.get("/search")
def search_venues(
    q: str = Query(..., min_length=1),
    lat: float = Query(...),
    lng: float = Query(...),
    enrich_area: bool = Query(False),
):
    query = q.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Query is required")

    cached_area_venues = load_cached_area_venues(lat, lng)
    matched_cached = []
    for venue in cached_area_venues:
        match_score = score_cached_match(venue, query)
        if match_score > 0:
            venue_copy = dict(venue)
            venue_copy["search_match_score"] = match_score
            matched_cached.append(venue_copy)

    matched_cached.sort(
        key=lambda v: (
            -(float(v.get("search_match_score", 0) or 0)),
            -(float(v.get("relevance_score", 0) or 0)),
            float(v.get("distance_km", 999) or 999),
        )
    )

    if matched_cached:
        best_match = matched_cached[0]
        related = [
            v for v in cached_area_venues
            if (v.get("place_id") or v.get("id")) != (best_match.get("place_id") or best_match.get("id"))
        ]
        return {
            "source": "firestore_search",
            "best_match": best_match,
            "related_venues": related[:12],
            "used_places_call": False,
        }

    search_results = search_places_by_text(query, lat, lng)
    save_venues_to_firestore(search_results)

    for venue in search_results:
        venue["yiyo_badge"] = get_venue_yiyo_badge(venue.get("place_id"))

    best_match = search_results[0] if search_results else None
    related_venues = search_results[1:13] if len(search_results) > 1 else []

    if enrich_area and best_match:
        enriched = fetch_nightlife_places(best_match["lat"], best_match["lng"])
        save_venues_to_firestore(enriched)

        seen = set()
        merged_related = []
        for item in related_venues + enriched:
            pid = item.get("place_id")
            if pid and pid not in seen and (not best_match or pid != best_match.get("place_id")):
                item["yiyo_badge"] = get_venue_yiyo_badge(pid)
                seen.add(pid)
                merged_related.append(item)
        related_venues = merged_related[:12]

    return {
        "source": "google_text_search",
        "best_match": best_match,
        "related_venues": related_venues,
        "used_places_call": True,
        "enriched_area": enrich_area and best_match is not None,
    }


@app.post("/reports")
def create_vibe_report(
    report: VibeReportCreate,
    current_user=Depends(get_current_user),
):
    try:
        uid = current_user.get("uid")
        email = current_user.get("email", "")
        display_name = current_user.get("name", "")

        if not uid:
            raise HTTPException(status_code=401, detail="Invalid user")

        if not report.comment and not report.parking_note:
            # still allow because structured fields matter; this just blocks truly empty shape abuse
            pass

        check_report_cooldown(uid, report.venue_id)

        reported_at = report.reported_at
        if not reported_at:
            reported_at = datetime.now(timezone.utc).isoformat()

        payload = {
            "venue_id": report.venue_id,
            "venue_name": report.venue_name,
            "crowd_level": report.crowd_level,
            "safety_level": report.safety_level,
            "music_type": report.music_type,
            "queue_length": report.queue_length,
            "yiyo_status": report.yiyo_status,
            "parking_availability": report.parking_availability,
            "parking_safety": report.parking_safety,
            "parking_note": report.parking_note or "",
            "comment": report.comment or "",
            "reported_at": reported_at,
            "created_at_unix": int(datetime.now(timezone.utc).timestamp()),
            "uid": uid,
            "user_email": email,
            "user_display_name": display_name,
        }

        doc_ref = db.collection(REPORTS_COLLECTION).document()
        doc_ref.set(payload)

        update_user_report_stats(uid)

        payload["id"] = doc_ref.id

        return {
            "message": "Report saved successfully",
            "report": payload,
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Failed to save report: {e}")
        raise HTTPException(status_code=500, detail="Failed to save report")


@app.get("/reports/{venue_id}")
def get_reports_for_venue(venue_id: str):
    try:
        docs = (
            db.collection(REPORTS_COLLECTION)
            .where(filter=FieldFilter("venue_id", "==", venue_id))
            .stream()
        )

        reports = [doc.to_dict() | {"id": doc.id} for doc in docs]

        reports.sort(
            key=lambda r: int(r.get("created_at_unix", 0)),
            reverse=True,
        )

        yiyo_badge = get_yiyo_badge_from_reports(reports[:12])

        return {
            "count": len(reports),
            "yiyo_badge": yiyo_badge,
            "reports": reports[:20],
        }

    except Exception as e:
        print(f"[ERROR] Failed to fetch reports for venue {venue_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch reports")