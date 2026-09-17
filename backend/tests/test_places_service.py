import pytest

from app.services.places_service import (
    _haversine_km,
    _normalize_place,
    _is_irrelevant,
    _score_venue,
    apply_discovery_context,
)


def test_haversine_same_location_is_zero():
    distance = _haversine_km(
        -26.2041,
        28.0473,
        -26.2041,
        28.0473,
    )

    assert distance == pytest.approx(0.0)


def test_normalize_place_returns_yiyo_venue_shape():
    place = {
        "place_id": "venue_123",
        "name": "Test Lounge",
        "geometry": {
            "location": {
                "lat": -26.2041,
                "lng": 28.0473,
            }
        },
        "rating": 4.5,
        "vicinity": "123 Test Street",
        "types": ["bar", "night_club"],
    }

    venue = _normalize_place(
        place,
        -26.2041,
        28.0473,
    )

    assert venue["place_id"] == "venue_123"
    assert venue["name"] == "Test Lounge"
    assert venue["lat"] == -26.2041
    assert venue["lng"] == 28.0473
    assert venue["rating"] == 4.5
    assert venue["address"] == "123 Test Street"
    assert venue["types"] == ["bar", "night_club"]
    assert venue["distance_km"] == 0.0


def test_irrelevant_business_is_filtered():
    venue = {
        "name": "Test Pharmacy",
        "types": ["pharmacy", "store"],
    }

    assert _is_irrelevant(venue) is True


def test_nightlife_name_prevents_false_irrelevant_filter():
    venue = {
        "name": "Downtown Cocktail Lounge",
        "types": ["restaurant"],
    }

    assert _is_irrelevant(venue) is False


def test_nightclub_scores_higher_than_generic_restaurant():
    nightclub = {
        "name": "Test Club",
        "types": ["night_club", "bar"],
        "rating": 4.5,
        "distance_km": 1.0,
    }

    restaurant = {
        "name": "Test Restaurant",
        "types": ["restaurant"],
        "rating": 4.5,
        "distance_km": 1.0,
    }

    assert _score_venue(nightclub) > _score_venue(restaurant)


def test_exact_search_match_gets_score_boost():
    venue = {
        "name": "Drama Bar",
        "types": ["bar"],
        "rating": 4.0,
        "distance_km": 2.0,
    }

    normal_score = _score_venue(venue)
    search_score = _score_venue(venue, query="Drama Bar")

    assert search_score > normal_score

def test_apply_discovery_context_adds_dynamic_fields():
    venue = {
        "place_id": "venue_123",
        "name": "Test Club",
        "lat": -26.2041,
        "lng": 28.0473,
        "rating": 4.5,
        "types": ["night_club"],
    }

    result = apply_discovery_context(
        venue,
        -26.2041,
        28.0473,
    )

    assert result["distance_km"] == 0.0
    assert "relevance_score" in result
    assert result["relevance_score"] > 0


def test_apply_discovery_context_does_not_mutate_venue():
    venue = {
        "place_id": "venue_123",
        "name": "Test Club",
        "lat": -26.2041,
        "lng": 28.0473,
        "rating": 4.5,
        "types": ["night_club"],
    }

    apply_discovery_context(
        venue,
        -26.2041,
        28.0473,
    )

    assert "distance_km" not in venue
    assert "relevance_score" not in venue

    