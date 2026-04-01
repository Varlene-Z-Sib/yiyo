import os
import math
import requests
from dotenv import load_dotenv

load_dotenv()

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
TEXT_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"

# Keep this small so first-time uncached calls stay cheap.
# This setup makes up to 4 Places requests for a brand-new area:
#   1) night_club nearby
#   2) bar nearby
#   3) text search: lounge
#   4) text search: piano bar
# After that, Firestore cache handles repeat loads for the same area.
MAX_RESULTS_RETURNED = 20


def _haversine_km(lat1, lng1, lat2, lng2):
    r = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)

    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


def _nearby_search(lat: float, lng: float, place_type: str, radius: int = 4000):
    params = {
        "location": f"{lat},{lng}",
        "radius": radius,
        "type": place_type,
        "key": GOOGLE_API_KEY,
    }

    response = requests.get(NEARBY_URL, params=params, timeout=20)
    response.raise_for_status()
    data = response.json()

    print(f"[DEBUG] Nearby Search status for {place_type}: {data.get('status')}")
    print(f"[DEBUG] Nearby Search results for {place_type}: {len(data.get('results', []))}")

    return data.get("results", [])


def _text_search(lat: float, lng: float, query: str, radius: int = 4000):
    params = {
        "query": query,
        "location": f"{lat},{lng}",
        "radius": radius,
        "key": GOOGLE_API_KEY,
    }

    response = requests.get(TEXT_SEARCH_URL, params=params, timeout=20)
    response.raise_for_status()
    data = response.json()

    print(f"[DEBUG] Text Search status for '{query}': {data.get('status')}")
    print(f"[DEBUG] Text Search results for '{query}': {len(data.get('results', []))}")

    return data.get("results", [])


def _normalize_place(place: dict, origin_lat: float, origin_lng: float):
    place_lat = place["geometry"]["location"]["lat"]
    place_lng = place["geometry"]["location"]["lng"]
    distance_km = _haversine_km(origin_lat, origin_lng, place_lat, place_lng)

    return {
        "place_id": place.get("place_id"),
        "name": place.get("name", "Unknown Venue"),
        "lat": place_lat,
        "lng": place_lng,
        "rating": place.get("rating", 0),
        "address": place.get("vicinity") or place.get("formatted_address", "No address available"),
        "types": place.get("types", []),
        "distance_km": round(distance_km, 2),
    }


def _contains_any(text: str, keywords: list[str]) -> bool:
    lowered = text.lower()
    return any(keyword in lowered for keyword in keywords)


def _is_irrelevant(venue: dict) -> bool:
    name = venue["name"].lower()
    types = [t.lower() for t in venue.get("types", [])]

    bad_types = {
        "school",
        "primary_school",
        "secondary_school",
        "hospital",
        "doctor",
        "dentist",
        "pharmacy",
        "physiotherapist",
        "gym",
        "health",
        "bank",
        "atm",
        "insurance_agency",
        "accounting",
        "lawyer",
        "real_estate_agency",
        "hardware_store",
        "electronics_store",
        "clothing_store",
        "shoe_store",
        "department_store",
        "furniture_store",
        "home_goods_store",
        "supermarket",
        "convenience_store",
        "grocery_or_supermarket",
        "pet_store",
        "florist",
        "car_repair",
        "car_wash",
        "gas_station",
        "laundry",
    }

    nightlife_keywords = [
        "club",
        "lounge",
        "bar",
        "piano",
        "cocktail",
        "roof",
        "pub",
        "tavern",
        "shisanyama",
        "social",
        "vip",
    ]

    # If the place has obviously irrelevant types and also doesn't sound nightlife-related, reject it.
    if any(t in bad_types for t in types) and not _contains_any(name, nightlife_keywords):
        return True

    return False


def _score_venue(venue: dict) -> float:
    score = 0.0
    name = venue["name"].lower()
    types = [t.lower() for t in venue.get("types", [])]
    rating = float(venue.get("rating", 0) or 0)
    distance_km = float(venue.get("distance_km", 999))

    # Type boosts
    if "night_club" in types:
        score += 45
    if "bar" in types:
        score += 25
    if "restaurant" in types:
        score += 4

    # Name boosts
    keyword_boosts = {
        "club": 22,
        "lounge": 25,
        "bar": 16,
        "piano": 20,
        "cocktail": 16,
        "roof": 12,
        "rooftop": 15,
        "pub": 10,
        "tavern": 8,
        "shisanyama": 10,
        "vip": 8,
    }

    for keyword, boost in keyword_boosts.items():
        if keyword in name:
            score += boost

    # Penalties for noisy result types
    noisy_penalties = {
        "store": 25,
        "gym": 50,
        "health": 35,
        "school": 60,
        "hospital": 60,
        "pharmacy": 50,
        "bank": 50,
        "atm": 50,
        "home_goods_store": 30,
    }

    for noisy_type, penalty in noisy_penalties.items():
        if noisy_type in types:
            score -= penalty

    # Rating boost
    score += rating * 6

    # Distance bonus (closer gets more points)
    if distance_km <= 1:
        score += 18
    elif distance_km <= 3:
        score += 10
    elif distance_km <= 5:
        score += 4
    else:
        score -= 4

    return round(score, 2)


def fetch_nightlife_places(lat: float, lng: float):
    raw_results = []

    # Nearby Search: strong for clubs/bars
    raw_results.extend(_nearby_search(lat, lng, "night_club"))
    raw_results.extend(_nearby_search(lat, lng, "bar"))

    # Text Search: helps catch names like "Piano Bar", "Lounge", etc.
    raw_results.extend(_text_search(lat, lng, "lounge"))
    raw_results.extend(_text_search(lat, lng, "piano bar"))

    # Normalize + dedupe by place_id
    merged = {}
    for place in raw_results:
        place_id = place.get("place_id")
        if not place_id:
            continue

        normalized = _normalize_place(place, lat, lng)

        # Keep the better version if duplicate appears
        existing = merged.get(place_id)
        if existing is None:
            merged[place_id] = normalized
        else:
            existing_rating = float(existing.get("rating", 0) or 0)
            new_rating = float(normalized.get("rating", 0) or 0)
            if new_rating > existing_rating:
                merged[place_id] = normalized

    venues = list(merged.values())

    # Filter junk
    venues = [venue for venue in venues if not _is_irrelevant(venue)]

    # Score venues
    for venue in venues:
        venue["relevance_score"] = _score_venue(venue)

    # Hard cut: remove very weak matches
    venues = [venue for venue in venues if venue["relevance_score"] >= 18]

    # Sort by relevance first, then distance, then rating
    venues.sort(
        key=lambda v: (
            -v["relevance_score"],
            v["distance_km"],
            -(float(v.get("rating", 0) or 0)),
        )
    )

    print(f"[DEBUG] Final filtered venues: {len(venues)}")

    return venues[:MAX_RESULTS_RETURNED]