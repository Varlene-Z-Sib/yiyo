from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="YIYO Backend")

# Allow Flutter app to call API
origins = [
    "http://localhost:5000",  # optional if you run frontend on web
    "http://10.0.2.2:5000",   # emulator localhost
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # allow all for testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sample venues
venues = [
    {"id": 1, "name": "Konka", "lat": -26.0656, "lng": 28.0026, "vibe": 9.2},
    {"id": 2, "name": "Rockets Bryanston", "lat": -26.0565, "lng": 28.0283, "vibe": 8.4},
    {"id": 3, "name": "Altitude Beach", "lat": -26.1060, "lng": 28.0567, "vibe": 7.9},
]

@app.get("/venues")
def get_venues():
    return {"venues": venues}