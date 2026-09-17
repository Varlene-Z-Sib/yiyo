from pydantic import BaseModel, ConfigDict, Field


class VenueRecord(BaseModel):
    """
    Canonical venue data that is safe to persist in Firestore.

    This represents what a venue IS, independent of the current user,
    search request, or community vibe state.
    """

    model_config = ConfigDict(extra="ignore")

    place_id: str
    name: str
    lat: float
    lng: float

    rating: float = 0.0
    address: str = "No address available"
    types: list[str] = Field(default_factory=list)

    google_last_refreshed_at: str | None = None
    google_last_refreshed_at_unix: int | None = None


class VenueDiscoveryItem(BaseModel):
    """
    Venue data returned for discovery/map requests.

    Includes stable venue identity plus request/community-derived fields.
    These dynamic fields should not be treated as canonical Firestore data.
    """

    model_config = ConfigDict(extra="ignore")

    place_id: str
    name: str
    lat: float
    lng: float

    rating: float = 0.0
    address: str = "No address available"
    types: list[str] = Field(default_factory=list)

    distance_km: float | None = None
    relevance_score: float | None = None
    yiyo_badge: str | None = None