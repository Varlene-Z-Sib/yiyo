from datetime import datetime, timezone

from app.services.yiyo_logic import (
    contributor_level_from_count,
    get_yiyo_badge_from_reports,
    is_cache_fresh,
    count_recent_actions,
    is_report_active,
    location_key_for,
    should_auto_flag_report,
)


def test_location_key_rounds_coordinates():
    key = location_key_for(
        -26.2041,
        28.0473,
    )

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
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    report_time = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "YIYO"
    )


def test_negative_recent_report_returns_not_yiyo():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    report_time = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "No",
            "crowd_level": "Dead",
            "safety_level": "Unsafe",
            "created_at_unix": report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "NOT YIYO"
    )


def test_neutral_report_returns_mid():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    report_time = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "Kind of",
            "crowd_level": "Chill",
            "safety_level": "Okay",
            "created_at_unix": report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "MID"
    )


def test_cache_is_fresh_within_ttl():
    now = 1_000_000
    refreshed_at = now - 3600

    assert (
        is_cache_fresh(
            refreshed_at,
            now,
            7 * 24 * 60 * 60,
        )
        is True
    )


def test_cache_is_stale_after_ttl():
    now = 1_000_000

    refreshed_at = (
        now - (7 * 24 * 60 * 60)
    )

    assert (
        is_cache_fresh(
            refreshed_at,
            now,
            7 * 24 * 60 * 60,
        )
        is False
    )


def test_cache_without_timestamp_is_stale():
    assert (
        is_cache_fresh(
            None,
            1_000_000,
            7 * 24 * 60 * 60,
        )
        is False
    )


def test_future_cache_timestamp_is_not_treated_as_fresh():
    assert (
        is_cache_fresh(
            1_000_100,
            1_000_000,
            7 * 24 * 60 * 60,
        )
        is False
    )


def test_report_older_than_24_hours_does_not_affect_badge():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    old_report_time = int(
        datetime(
            2026,
            9,
            17,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": old_report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "MID"
    )


def test_recent_report_still_affects_badge():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    recent_report_time = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": recent_report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "YIYO"
    )


def test_future_report_does_not_affect_badge():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    future_report_time = int(
        datetime(
            2026,
            9,
            18,
            13,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": future_report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "MID"
    )


def test_legacy_report_without_status_is_active():
    report = {
        "yiyo_status": "Kind of",
    }

    assert is_report_active(report) is True


def test_explicit_active_report_is_active():
    report = {
        "status": "active",
    }

    assert is_report_active(report) is True


def test_flagged_and_removed_reports_are_not_active():
    assert (
        is_report_active(
            {"status": "flagged"}
        )
        is False
    )

    assert (
        is_report_active(
            {"status": "removed"}
        )
        is False
    )


def test_flagged_report_does_not_affect_badge():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    report_time = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "flagged",
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "created_at_unix": report_time,
        }
    ]

    assert (
        get_yiyo_badge_from_reports(
            reports,
            now=now,
        )
        == "MID"
    )

def test_report_is_not_auto_flagged_below_threshold():
    assert should_auto_flag_report(0) is False
    assert should_auto_flag_report(1) is False
    assert should_auto_flag_report(2) is False


def test_report_is_auto_flagged_at_threshold():
    assert should_auto_flag_report(3) is True


def test_report_remains_auto_flagged_above_threshold():
    assert should_auto_flag_report(4) is True
    assert should_auto_flag_report(10) is True

def test_count_recent_actions_inside_window():
    now = 10_000

    timestamps = [
        9_900,
        9_500,
        8_000,
    ]

    assert (
        count_recent_actions(
            timestamps,
            now_unix=now,
            window_seconds=1000,
        )
        == 2
    )


def test_count_recent_actions_ignores_old_actions():
    now = 10_000

    timestamps = [
        1_000,
        2_000,
        3_000,
    ]

    assert (
        count_recent_actions(
            timestamps,
            now_unix=now,
            window_seconds=1000,
        )
        == 0
    )


def test_count_recent_actions_ignores_future_timestamps():
    now = 10_000

    timestamps = [
        10_100,
        10_500,
    ]

    assert (
        count_recent_actions(
            timestamps,
            now_unix=now,
            window_seconds=1000,
        )
        == 0
    )