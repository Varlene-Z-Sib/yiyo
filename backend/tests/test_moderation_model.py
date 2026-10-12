import pytest

from pydantic import ValidationError

from app.models.moderation_model import (
    ModerationDecision,
    ModerationResolutionRequest,
)


def test_keep_resolution():
    request = (
        ModerationResolutionRequest(
            decision="keep",
            note="Looks legitimate.",
        )
    )

    assert (
        request.decision
        == ModerationDecision.KEEP
    )

    assert (
        request.note
        == "Looks legitimate."
    )


def test_remove_resolution():
    request = (
        ModerationResolutionRequest(
            decision="remove",
        )
    )

    assert (
        request.decision
        == ModerationDecision.REMOVE
    )


def test_invalid_resolution_rejected():
    with pytest.raises(
        ValidationError
    ):
        ModerationResolutionRequest(
            decision="ban",
        )


def test_note_length_is_limited():
    with pytest.raises(
        ValidationError
    ):
        ModerationResolutionRequest(
            decision="keep",
            note="x" * 1001,
        )