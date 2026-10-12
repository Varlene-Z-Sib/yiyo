from app.services.moderation_service import (
    _flag_summary,
    _is_open_flag,
)


def test_missing_flag_status_is_open():
    assert _is_open_flag(
        {}
    )


def test_open_flag_is_open():
    assert _is_open_flag(
        {
            "status":
                "open",
        }
    )


def test_resolved_flag_is_not_open():
    assert not _is_open_flag(
        {
            "status":
                "resolved",
        }
    )


def test_flag_summary_groups_reasons():
    summary = _flag_summary(
        [
            {
                "reason":
                    "spam",

                "details":
                    "Repeated listing",

                "created_at":
                    "2026-10-12T08:00:00+00:00",

                "created_at_unix":
                    100,
            },
            {
                "reason":
                    "spam",

                "details":
                    "Repeated listing",

                "created_at":
                    "2026-10-12T09:00:00+00:00",

                "created_at_unix":
                    200,
            },
            {
                "reason":
                    "safety_concern",

                "details":
                    "Venue detail seems unsafe",

                "created_at":
                    "2026-10-12T10:00:00+00:00",

                "created_at_unix":
                    300,
            },
        ]
    )

    assert (
        summary["flag_count"]
        == 3
    )

    assert (
        summary["reasons"]["spam"]
        == 2
    )

    assert (
        summary[
            "reasons"
        ][
            "safety_concern"
        ]
        == 1
    )

    assert (
        len(
            summary["details"]
        )
        == 2
    )

    assert (
        summary[
            "latest_flagged_at_unix"
        ]
        == 300
    )