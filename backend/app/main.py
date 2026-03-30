from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from app.services.places_service import fetch_nightlife_places
from app.firebase_config import db

app = FastAPI(title="YIYO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "YIYO Backend Running 🚀"}


@app.get("/venues")
def get_venues(
    lat: float = Query(...),
    lng: float = Query(...),
):
    # 🔑 Use rounded location as cache key
    location_key = f"{round(lat, 2)}_{round(lng, 2)}"

    # 1. CHECK FIRESTORE FIRST (FREE)
    docs = db.collection("venues").where("location_key", "==", location_key).stream()
    cached = [doc.to_dict() for doc in docs]

    if cached:
        return {
            "source": "firestore_cache",
            "count": len(cached),
            "venues": cached
        }

    # 2. ONLY CALL GOOGLE IF NO CACHE
    venues = fetch_nightlife_places(lat, lng)

    # 3. SAVE WITH UNIQUE ID (NO DUPLICATES)
    for venue in venues:
        place_id = venue.get("place_id") + str(venue.get("lat"))  # fallback ID

        venue["location_key"] = location_key

        db.collection("venues").document(place_id).set(venue)

    return {
        "source": "google_places",
        "count": len(venues),
        "venues": venues
    }