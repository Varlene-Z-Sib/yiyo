from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.services.places_service import fetch_nightlife_places

app = FastAPI(title="YIYO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

COLLECTION_NAME = "venues_v2"


@app.get("/")
def root():
    return {"message": "YIYO Backend Running 🚀"}


@app.get("/venues")
def get_venues(
    lat: float = Query(...),
    lng: float = Query(...),
):
    rounded_lat = round(lat, 2)
    rounded_lng = round(lng, 2)
    location_key = f"{rounded_lat}_{rounded_lng}"

    print(f"[DEBUG] location_key = {location_key}")

    # 1. Check Firestore cache first
    docs = (
        db.collection(COLLECTION_NAME)
        .where(filter=FieldFilter("location_key", "==", location_key))
        .stream()
    )

    cached_venues = [doc.to_dict() for doc in docs]

    if cached_venues:
        cached_venues.sort(
            key=lambda v: (
                -(float(v.get("relevance_score", 0) or 0)),
                float(v.get("distance_km", 999) or 999),
                -(float(v.get("rating", 0) or 0)),
            )
        )

        return {
            "source": "firestore_cache",
            "count": len(cached_venues),
            "venues": cached_venues,
        }

    # 2. Only call Places if not cached
    venues = fetch_nightlife_places(lat, lng)

    saved_count = 0
    skipped_count = 0

    # 3. Save ranked venues to Firestore
    for venue in venues:
        try:
            place_id = venue.get("place_id")
            if not place_id:
                skipped_count += 1
                continue

            venue["location_key"] = location_key

            db.collection(COLLECTION_NAME).document(place_id).set(venue)
            saved_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to save venue {venue.get('name')}: {e}")

    return {
        "source": "google_places",
        "count": len(venues),
        "saved_count": saved_count,
        "skipped_count": skipped_count,
        "venues": venues,
    }