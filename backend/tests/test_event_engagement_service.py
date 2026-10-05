from app.models.event_engagement_model import (
    EventReactionType,
)

from app.services.event_engagement_service import (
    _counter_field,
    _reaction_document_id,
    _safe_count,
    calculate_reaction_toggle,
)


def test_adding_reaction_increments_count():
    active, count = (
        calculate_reaction_toggle(
            current_count=5,
            reaction_exists=False,
        )
    )

    assert active is True
    assert count == 6


def test_removing_reaction_decrements_count():
    active, count = (
        calculate_reaction_toggle(
            current_count=5,
            reaction_exists=True,
        )
    )

    assert active is False
    assert count == 4


def test_removing_reaction_never_goes_negative():
    active, count = (
        calculate_reaction_toggle(
            current_count=0,
            reaction_exists=True,
        )
    )

    assert active is False
    assert count == 0


def test_reaction_document_id_is_deterministic():
    first = (
        _reaction_document_id(
            event_id="event_123",
            uid="user_456",
            reaction=
                EventReactionType.HYPE,
        )
    )

    second = (
        _reaction_document_id(
            event_id="event_123",
            uid="user_456",
            reaction=
                EventReactionType.HYPE,
        )
    )

    assert first == second


def test_different_reaction_types_get_different_ids():
    hype_id = (
        _reaction_document_id(
            event_id="event_123",
            uid="user_456",
            reaction=
                EventReactionType.HYPE,
        )
    )

    going_id = (
        _reaction_document_id(
            event_id="event_123",
            uid="user_456",
            reaction=
                EventReactionType.GOING,
        )
    )

    assert hype_id != going_id


def test_reaction_types_use_correct_counter():
    assert (
        _counter_field(
            EventReactionType.HYPE
        )
        == "hype_count"
    )

    assert (
        _counter_field(
            EventReactionType.GOING
        )
        == "going_count"
    )


def test_safe_count_handles_bad_values():
    assert _safe_count(None) == 0
    assert _safe_count("4") == 4
    assert _safe_count(-5) == 0
    assert _safe_count("bad") == 0