from app.models.venue_model import (
    VenueDiscoveryItem,
    VenueRecord,
)


def test_venue_record_contains_canonical_fields():
    venue = VenueRecord(
        place_id="place_123",
        name="Test Lounge",
        lat=-26.2041,
        lng=28.0473,
        rating=4.5,
        address="123 Test Street",
        types=["bar", "night_club"],
    )

    assert venue.place_id == "place_123"
    assert venue.name == "Test Lounge"
    assert venue.lat == -26.2041
    assert venue.lng == 28.0473
    assert venue.rating == 4.5
    assert venue.address == "123 Test Street"
    assert venue.types == ["bar", "night_club"]


def test_venue_record_ignores_discovery_only_fields():
    venue = VenueRecord(
        place_id="place_123",
        name="Test Lounge",
        lat=-26.2041,
        lng=28.0473,
        distance_km=1.5,
        relevance_score=42.0,
        yiyo_badge="YIYO",
        location_key="-26.20_28.05",
    )

    stored = venue.model_dump()

    assert "distance_km" not in stored
    assert "relevance_score" not in stored
    assert "yiyo_badge" not in stored
    assert "location_key" not in stored


def test_venue_record_has_safe_defaults():
    venue = VenueRecord(
        place_id="place_123",
        name="Basic Venue",
        lat=-26.0,
        lng=28.0,
    )

    assert venue.rating == 0.0
    assert venue.address == "No address available"
    assert venue.types == []
    assert venue.google_last_refreshed_at is None
    assert venue.google_last_refreshed_at_unix is None


def test_discovery_item_keeps_dynamic_fields():
    venue = VenueDiscoveryItem(
        place_id="place_123",
        name="Test Lounge",
        lat=-26.2041,
        lng=28.0473,
        rating=4.5,
        address="123 Test Street",
        types=["bar"],
        distance_km=2.4,
        relevance_score=38.0,
        yiyo_badge="YIYO",
    )

    assert venue.distance_km == 2.4
    assert venue.relevance_score == 38.0
    assert venue.yiyo_badge == "YIYO"


def test_discovery_item_does_not_require_dynamic_fields():
    venue = VenueDiscoveryItem(
        place_id="place_123",
        name="Test Lounge",
        lat=-26.2041,
        lng=28.0473,
    )

    assert venue.distance_km is None
    assert venue.relevance_score is None
    assert venue.yiyo_badge is None