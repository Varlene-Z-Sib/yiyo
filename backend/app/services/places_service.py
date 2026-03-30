import requests
from app.config import GOOGLE_API_KEY

BASE_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"


def fetch_nightlife_places(lat: float, lng: float, radius: int = 3000):
    params = {
        "location": f"{lat},{lng}",
        "radius": radius,
        "type": "night_club",  # key filter
        "keyword": "club|lounge|bar",  # extra filtering
        "key": GOOGLE_API_KEY
    }

    response = requests.get(BASE_URL, params=params)
    data = response.json()

    results = []

    for place in data.get("results", []):
        results.append({
            "place_id": place.get("place_id"),  #  UNIQUE ID
            "name": place.get("name"),
            "lat": place["geometry"]["location"]["lat"],
            "lng": place["geometry"]["location"]["lng"],
            "rating": place.get("rating", 0),
            "address": place.get("vicinity"),
            "types": place.get("types", [])
        })

    return results