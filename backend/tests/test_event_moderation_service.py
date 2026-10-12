from app.services.event_moderation_service import (
    _event_flag_id,
)


def test_event_flag_id_is_stable():
    first = _event_flag_id(
        "event_123",
        "user_123",
    )

    second = _event_flag_id(
        "event_123",
        "user_123",
    )

    assert first == second
    assert len(first) == 64


def test_event_flag_id_changes_by_user():
    first = _event_flag_id(
        "event_123",
        "user_a",
    )

    second = _event_flag_id(
        "event_123",
        "user_b",
    )

    assert first != second