from datetime import datetime, timezone

import app.services.materialized_vibe_service as materialized_service
from app.services.materialized_vibe_service import (
    MATERIALIZED_REPORT_LIMIT,
    build_materialized_summary_document,
    current_state_from_materialized_document,
)


def _timestamp(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int = 0,
) -> int:
    return int(
        datetime(
            year,
            month,
            day,
            hour,
            minute,
            tzinfo=timezone.utc,
        ).timestamp()
    )


def test_materialized_document_contains_current_state():
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
            "created_at_unix": _timestamp(
                2026,
                9,
                18,
                11,
            ),
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
            "music_type": "Amapiano",
            "queue_length": "Short",
            "parking_availability": "Available",
            "parking_safety": "Safe",
        }
    ]

    document = (
        build_materialized_summary_document(
            venue_id="venue_123",
            reports=reports,
            now=now,
        )
    )

    assert (
        document["venue_id"]
        == "venue_123"
    )

    assert (
        document["yiyo_badge"]
        == "YIYO"
    )

    assert (
        document["summary"][
            "report_count"
        ]
        == 1
    )

    assert (
        document["summary"][
            "crowd"
        ]["value"]
        == "Packed"
    )

    assert (
        len(
            document[
                "recent_reports"
            ]
        )
        == 1
    )


def test_materialized_document_excludes_moderated_reports():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    created_at = _timestamp(
        2026,
        9,
        18,
        11,
    )

    reports = [
        {
            "status": "active",
            "created_at_unix": created_at,
            "yiyo_status": "Kind of",
            "crowd_level": "Busy",
            "safety_level": "Okay",
        },
        {
            "status": "flagged",
            "created_at_unix": created_at,
            "yiyo_status": "Yes definitely",
            "crowd_level": "Packed",
            "safety_level": "Safe",
        },
        {
            "status": "removed",
            "created_at_unix": created_at,
            "yiyo_status": "No",
            "crowd_level": "Dead",
            "safety_level": "Unsafe",
        },
    ]

    document = (
        build_materialized_summary_document(
            venue_id="venue_123",
            reports=reports,
            now=now,
        )
    )

    assert (
        len(
            document[
                "recent_reports"
            ]
        )
        == 1
    )

    assert (
        document[
            "recent_reports"
        ][0]["crowd_level"]
        == "Busy"
    )


def test_materialized_document_is_bounded():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    reports = []

    for index in range(
        MATERIALIZED_REPORT_LIMIT + 20
    ):
        reports.append(
            {
                "status": "active",
                "created_at_unix": (
                    _timestamp(
                        2026,
                        9,
                        18,
                        11,
                    )
                    - index
                ),
                "yiyo_status": "Kind of",
                "crowd_level": "Busy",
                "safety_level": "Okay",
            }
        )

    document = (
        build_materialized_summary_document(
            venue_id="venue_123",
            reports=reports,
            now=now,
        )
    )

    assert (
        len(
            document[
                "recent_reports"
            ]
        )
        == MATERIALIZED_REPORT_LIMIT
    )


def test_materialized_state_expires_without_rebuild():
    build_time = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    report_time = _timestamp(
        2026,
        9,
        18,
        11,
    )

    document = (
        build_materialized_summary_document(
            venue_id="venue_123",
            reports=[
                {
                    "status": "active",
                    "created_at_unix": report_time,
                    "yiyo_status": "Yes definitely",
                    "crowd_level": "Packed",
                    "safety_level": "Safe",
                }
            ],
            now=build_time,
        )
    )

    initial_state = (
        current_state_from_materialized_document(
            document,
            now=build_time,
        )
    )

    assert (
        initial_state[
            "yiyo_badge"
        ]
        == "YIYO"
    )

    assert (
        initial_state[
            "summary"
        ].report_count
        == 1
    )

    later = datetime(
        2026,
        9,
        19,
        13,
        tzinfo=timezone.utc,
    )

    later_state = (
        current_state_from_materialized_document(
            document,
            now=later,
        )
    )

    assert (
        later_state[
            "yiyo_badge"
        ]
        == "MID"
    )

    assert (
        later_state[
            "summary"
        ].report_count
        == 0
    )


def test_missing_materialized_document_returns_safe_defaults():
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    state = (
        current_state_from_materialized_document(
            None,
            now=now,
        )
    )

    assert (
        state["yiyo_badge"]
        == "MID"
    )

    assert (
        state[
            "summary"
        ].report_count
        == 0
    )


def test_materialized_summary_preserves_consensus():
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
            "created_at_unix": _timestamp(
                2026,
                9,
                18,
                11,
                50,
            ),
            "yiyo_status": "Yes definitely",
            "crowd_level": "Busy",
            "safety_level": "Safe",
            "music_type": "Amapiano",
        },
        {
            "status": "active",
            "created_at_unix": _timestamp(
                2026,
                9,
                18,
                11,
                40,
            ),
            "yiyo_status": "Yes definitely",
            "crowd_level": "Busy",
            "safety_level": "Safe",
            "music_type": "Amapiano",
        },
        {
            "status": "active",
            "created_at_unix": _timestamp(
                2026,
                9,
                18,
                11,
                30,
            ),
            "yiyo_status": "Kind of",
            "crowd_level": "Packed",
            "safety_level": "Okay",
            "music_type": "House",
        },
    ]

    document = (
        build_materialized_summary_document(
            venue_id="venue_123",
            reports=reports,
            now=now,
        )
    )

    state = (
        current_state_from_materialized_document(
            document,
            now=now,
        )
    )

    summary = state[
        "summary"
    ]

    assert (
        summary.report_count
        == 3
    )

    assert (
        summary.crowd.value
        == "Busy"
    )

    assert (
        summary.crowd.agreement_count
        == 2
    )

    assert (
        summary.safety.value
        == "Safe"
    )

    assert (
        summary.music.value
        == "Amapiano"
    )


def test_safe_rebuild_returns_true_when_rebuild_succeeds(
    monkeypatch,
):
    def fake_rebuild(
        venue_id: str,
    ):
        return {
            "venue_id": venue_id,
        }

    monkeypatch.setattr(
        materialized_service,
        "rebuild_venue_community_summary",
        fake_rebuild,
    )

    result = (
        materialized_service
        .safe_rebuild_venue_community_summary(
            "venue_123"
        )
    )

    assert result is True


def test_safe_rebuild_returns_false_without_raising(
    monkeypatch,
):
    def fake_rebuild(
        venue_id: str,
    ):
        raise RuntimeError(
            "Firestore unavailable"
        )

    monkeypatch.setattr(
        materialized_service,
        "rebuild_venue_community_summary",
        fake_rebuild,
    )

    result = (
        materialized_service
        .safe_rebuild_venue_community_summary(
            "venue_123"
        )
    )

    assert result is False

def test_attach_materialized_states_enriches_venues(
    monkeypatch,
):
    now = datetime(
        2026,
        9,
        18,
        12,
        tzinfo=timezone.utc,
    )

    summary = (
        materialized_service
        .build_current_vibe_summary(
            [
                {
                    "status":
                        "active",

                    "created_at_unix":
                        _timestamp(
                            2026,
                            9,
                            18,
                            11,
                        ),

                    "crowd_level":
                        "Busy",
                }
            ],
            now=now,
        )
    )

    def fake_get_states(
        venue_ids,
        now=None,
    ):
        assert venue_ids == [
            "venue_1",
            "venue_2",
        ]

        return {
            "venue_1": {
                "yiyo_badge":
                    "YIYO",

                "summary":
                    summary,
            },

            "venue_2": {
                "yiyo_badge":
                    "MID",

                "summary":
                    materialized_service
                    .build_current_vibe_summary(
                        [],
                        now=now,
                    ),
            },
        }

    monkeypatch.setattr(
        materialized_service,
        "get_materialized_community_states",
        fake_get_states,
    )

    venues = [
        {
            "place_id":
                "venue_1",

            "name":
                "Venue One",
        },
        {
            "place_id":
                "venue_2",

            "name":
                "Venue Two",
        },
    ]

    result = (
        materialized_service
        .attach_materialized_community_states(
            venues,
            now=now,
        )
    )

    assert (
        result[0][
            "yiyo_badge"
        ]
        == "YIYO"
    )

    assert (
        result[0][
            "current_vibe_summary"
        ]["report_count"]
        == 1
    )

    assert (
        result[1][
            "yiyo_badge"
        ]
        == "MID"
    )


def test_attach_materialized_states_handles_missing_venue_id(
    monkeypatch,
):
    def fake_get_states(
        venue_ids,
        now=None,
    ):
        assert venue_ids == []

        return {}

    monkeypatch.setattr(
        materialized_service,
        "get_materialized_community_states",
        fake_get_states,
    )

    venues = [
        {
            "name":
                "Venue Without ID",
        }
    ]

    result = (
        materialized_service
        .attach_materialized_community_states(
            venues
        )
    )

    assert (
        result[0][
            "yiyo_badge"
        ]
        == "MID"
    )

    assert (
        result[0][
            "current_vibe_summary"
        ]["report_count"]
        == 0
    )