import pytest

from fastapi import HTTPException

from app.services.blocking_service import (
    _block_document_id,
    _store_block,
)


def test_block_document_id_is_stable():
    first = _block_document_id(
        "user_a",
        "user_b",
    )

    second = _block_document_id(
        "user_a",
        "user_b",
    )

    assert first == second
    assert len(first) == 64


def test_block_direction_changes_id():
    forward = _block_document_id(
        "user_a",
        "user_b",
    )

    reverse = _block_document_id(
        "user_b",
        "user_a",
    )

    assert forward != reverse


def test_user_cannot_block_self():
    with pytest.raises(
        HTTPException
    ) as error:
        _store_block(
            blocker_uid=
                "user_123",

            blocked_uid=
                "user_123",

            source_type=
                "vibe_report",

            source_id=
                "report_123",
        )

    assert (
        error.value.status_code
        == 400
    )