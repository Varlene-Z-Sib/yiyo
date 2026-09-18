from datetime import datetime, timezone

from app.services.vibe_summary_service import (
    build_current_vibe_summary,
)


def test_empty_reports_return_empty_summary():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    summary = (
        build_current_vibe_summary(
            [],
            now=now,
        )
    )

    assert summary.report_count == 0
    assert (
        summary.latest_created_at_unix
        is None
    )
    assert summary.crowd.value is None
    assert (
        summary.crowd.agreement_count
        == 0
    )


def test_summary_uses_only_current_active_reports():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    recent = int(
        datetime(
            2026,
            9,
            18,
            11,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    old = int(
        datetime(
            2026,
            9,
            17,
            10,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "crowd_level": "Busy",
            "created_at_unix": recent,
        },
        {
            "status": "flagged",
            "crowd_level": "Packed",
            "created_at_unix": recent,
        },
        {
            "status": "active",
            "crowd_level": "Dead",
            "created_at_unix": old,
        },
    ]

    summary = (
        build_current_vibe_summary(
            reports,
            now=now,
        )
    )

    assert summary.report_count == 1
    assert summary.crowd.value == "Busy"
    assert (
        summary.crowd.agreement_count
        == 1
    )


def test_summary_uses_majority_consensus():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    reports = [
        {
            "status": "active",
            "crowd_level": "Busy",
            "safety_level": "Safe",
            "created_at_unix": int(
                datetime(
                    2026,
                    9,
                    18,
                    11,
                    50,
                    tzinfo=timezone.utc,
                ).timestamp()
            ),
        },
        {
            "status": "active",
            "crowd_level": "Busy",
            "safety_level": "Safe",
            "created_at_unix": int(
                datetime(
                    2026,
                    9,
                    18,
                    11,
                    40,
                    tzinfo=timezone.utc,
                ).timestamp()
            ),
        },
        {
            "status": "active",
            "crowd_level": "Packed",
            "safety_level": "Okay",
            "created_at_unix": int(
                datetime(
                    2026,
                    9,
                    18,
                    11,
                    30,
                    tzinfo=timezone.utc,
                ).timestamp()
            ),
        },
    ]

    summary = (
        build_current_vibe_summary(
            reports,
            now=now,
        )
    )

    assert summary.report_count == 3

    assert summary.crowd.value == "Busy"
    assert (
        summary.crowd.agreement_count
        == 2
    )

    assert summary.safety.value == "Safe"
    assert (
        summary.safety.agreement_count
        == 2
    )


def test_newest_value_wins_consensus_tie():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    reports = [
        {
            "status": "active",
            "music_type": "Amapiano",
            "created_at_unix": int(
                datetime(
                    2026,
                    9,
                    18,
                    11,
                    50,
                    tzinfo=timezone.utc,
                ).timestamp()
            ),
        },
        {
            "status": "active",
            "music_type": "House",
            "created_at_unix": int(
                datetime(
                    2026,
                    9,
                    18,
                    11,
                    40,
                    tzinfo=timezone.utc,
                ).timestamp()
            ),
        },
    ]

    summary = (
        build_current_vibe_summary(
            reports,
            now=now,
        )
    )

    assert (
        summary.music.value
        == "Amapiano"
    )

    assert (
        summary.music.agreement_count
        == 1
    )


def test_summary_tracks_latest_report_time():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    newest = int(
        datetime(
            2026,
            9,
            18,
            11,
            55,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    older = int(
        datetime(
            2026,
            9,
            18,
            11,
            20,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    reports = [
        {
            "status": "active",
            "queue_length": "Short",
            "created_at_unix": older,
        },
        {
            "status": "active",
            "queue_length": "Short",
            "created_at_unix": newest,
        },
    ]

    summary = (
        build_current_vibe_summary(
            reports,
            now=now,
        )
    )

    assert (
        summary.latest_created_at_unix
        == newest
    )

    assert summary.queue.value == "Short"

    assert (
        summary.queue.agreement_count
        == 2
    )