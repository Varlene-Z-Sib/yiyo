from datetime import (
    datetime,
    timezone,
)

import pytest

from fastapi import HTTPException

from app.models.event_model import (
    EventStatus,
)

from app.services.account_deletion_service import (
    _event_owner_cleanup_update,
    _safe_int,
    require_recent_auth,
)


def test_recent_auth_accepts_fresh_login():
    uid = require_recent_auth(
        {
            "uid":
                "user_123",

            "auth_time":
                1000,
        },

        now_unix=
            1100,
    )

    assert uid == "user_123"


def test_recent_auth_rejects_old_login():
    with pytest.raises(
        HTTPException
    ) as error:
        require_recent_auth(
            {
                "uid":
                    "user_123",

                "auth_time":
                    1000,
            },

            now_unix=
                1400,
        )

    assert (
        error.value.status_code
        == 401
    )


def test_recent_auth_requires_auth_time():
    with pytest.raises(
        HTTPException
    ) as error:
        require_recent_auth(
            {
                "uid":
                    "user_123",
            },

            now_unix=
                1000,
        )

    assert (
        error.value.status_code
        == 401
    )


def test_pending_event_is_cancelled_when_owner_deleted():
    now = datetime(
        2026,
        10,
        8,
        8,
        0,
        tzinfo=
            timezone.utc,
    )

    update = (
        _event_owner_cleanup_update(
            status=
                EventStatus
                .PENDING
                .value,

            now=
                now,
        )
    )

    assert (
        update["status"]
        ==
        EventStatus
        .CANCELLED
        .value
    )

    assert (
        update["organizer_uid"]
        == ""
    )

    assert (
        update[
            "organizer_deleted"
        ]
        is True
    )


def test_published_event_remains_published():
    now = datetime(
        2026,
        10,
        8,
        8,
        0,
        tzinfo=
            timezone.utc,
    )

    update = (
        _event_owner_cleanup_update(
            status=
                EventStatus
                .PUBLISHED
                .value,

            now=
                now,
        )
    )

    assert (
        "status"
        not in update
    )

    assert (
        update["organizer_uid"]
        == ""
    )


def test_safe_int_never_returns_negative():
    assert _safe_int(5) == 5
    assert _safe_int("4") == 4
    assert _safe_int(-8) == 0
    assert _safe_int("bad") == 0