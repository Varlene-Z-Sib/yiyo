from datetime import datetime, timezone

from app.services.yiyo_logic import (
    location_key_for,
    contributor_level_from_count,
    get_yiyo_badge_from_reports,
    is_cache_fresh,
)


def test_location_key_rounds_coordinates():
    key = location_key_for(-26.2041, 28.0473)

    assert key == "-26.2_28.05"


def test_contributor_levels():
    assert contributor_level_from_count(0) == "Rookie"
    assert contributor_level_from_count(4) == "Rookie"

    assert contributor_level_from_count(5) == "Active"
    assert contributor_level_from_count(19) == "Active"

    assert contributor_level_from_count(20) == "Scout"
    assert contributor_level_from_count(49) == "Scout"

    assert contributor_level_from_count(50) == "Legend"


def test_no_reports_returns_mid():
    assert get_yiyo_badge_from_reports([]) == "MID"


def test_positive_recent_report_returns_yiyo():
    now = int(datetime.now(timezone.utc).timestamp())

    reports = [
        {
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": now,
        }
    ]

    assert get_yiyo_badge_from_reports(reports) == "YIYO"


def test_negative_recent_report_returns_not_yiyo():
    now = int(datetime.now(timezone.utc).timestamp())

    reports = [
        {
            "yiyo_status": "No",
            "crowd_level": "Dead",
            "safety_level": "Unsafe",
            "created_at_unix": now,
        }
    ]

    assert get_yiyo_badge_from_reports(reports) == "NOT YIYO"


def test_neutral_report_returns_mid():
    now = int(datetime.now(timezone.utc).timestamp())

    reports = [
        {
            "yiyo_status": "Kind of",
            "crowd_level": "Chill",
            "safety_level": "Okay",
            "created_at_unix": now,
        }
    ]

    assert get_yiyo_badge_from_reports(reports) == "MID"

def test_cache_is_fresh_within_ttl():
    now = 1_000_000
    refreshed_at = now - 3600

    assert is_cache_fresh(
        refreshed_at,
        now,
        7 * 24 * 60 * 60,
    ) is True


def test_cache_is_stale_after_ttl():
    now = 1_000_000
    refreshed_at = now - (7 * 24 * 60 * 60)

    assert is_cache_fresh(
        refreshed_at,
        now,
        7 * 24 * 60 * 60,
    ) is False


def test_cache_without_timestamp_is_stale():
    assert is_cache_fresh(
        None,
        1_000_000,
        7 * 24 * 60 * 60,
    ) is False


def test_future_cache_timestamp_is_not_treated_as_fresh():
    assert is_cache_fresh(
        1_000_100,
        1_000_000,
        7 * 24 * 60 * 60,
    ) is False