from datetime import (
    datetime,
    timedelta,
    timezone,
)

import pytest

from fastapi import HTTPException
from pydantic import ValidationError

from app.models.authorization_model import (
    AppRole,
    EffectivePermissions,
)

from app.models.event_model import (
    EventCreate,
    EventStatus,
)

from app.services.event_service import (
    can_cancel_event_with_context,
    can_review_event_with_context,
    determine_initial_event_status,
    event_visibility_end,
    is_event_pending_approval,
    is_event_status_cancellable,
    validate_event_is_future,
)


def _permissions(
    *,
    app_role: AppRole = AppRole.USER,
    is_promoter: bool = False,
    managed_venue_ids: list[str] | None = None,
) -> EffectivePermissions:
    managed = (
        managed_venue_ids
        or []
    )

    return EffectivePermissions(
        uid="user_123",

        app_role=app_role,

        is_promoter=
            is_promoter,

        managed_venue_ids=
            managed,

        moderate_content=(
            app_role
            in {
                AppRole.MODERATOR,
                AppRole.SUPER_ADMIN,
            }
        ),

        super_admin=(
            app_role
            == AppRole.SUPER_ADMIN
        ),

        create_events=(
            is_promoter
            or bool(managed)
            or app_role
            == AppRole.SUPER_ADMIN
        ),

        manage_venues=(
            bool(managed)
            or app_role
            == AppRole.SUPER_ADMIN
        ),
    )


def test_event_requires_timezone():
    with pytest.raises(
        ValidationError
    ):
        EventCreate(
            title="Friday Night",
            venue_id="venue_123",
            starts_at=datetime(
                2026,
                10,
                2,
                20,
            ),
        )


def test_event_end_must_be_after_start():
    start = datetime(
        2026,
        10,
        2,
        20,
        tzinfo=timezone.utc,
    )

    with pytest.raises(
        ValidationError
    ):
        EventCreate(
            title="Friday Night",
            venue_id="venue_123",
            starts_at=start,
            ends_at=(
                start
                - timedelta(
                    hours=1
                )
            ),
        )


def test_promoter_event_starts_pending():
    status = (
        determine_initial_event_status(
            _permissions(
                is_promoter=True
            ),
            "venue_123",
        )
    )

    assert (
        status
        == EventStatus.PENDING
    )


def test_venue_manager_event_for_own_venue_is_published():
    status = (
        determine_initial_event_status(
            _permissions(
                managed_venue_ids=[
                    "venue_123"
                ]
            ),
            "venue_123",
        )
    )

    assert (
        status
        == EventStatus.PUBLISHED
    )


def test_venue_manager_cannot_create_for_other_venue():
    with pytest.raises(
        HTTPException
    ) as error:
        determine_initial_event_status(
            _permissions(
                managed_venue_ids=[
                    "venue_123"
                ]
            ),
            "venue_other",
        )

    assert (
        error.value.status_code
        == 403
    )


def test_super_admin_can_publish_anywhere():
    status = (
        determine_initial_event_status(
            _permissions(
                app_role=
                    AppRole
                    .SUPER_ADMIN
            ),
            "any_venue",
        )
    )

    assert (
        status
        == EventStatus.PUBLISHED
    )


def test_regular_user_cannot_create_event():
    with pytest.raises(
        HTTPException
    ) as error:
        determine_initial_event_status(
            _permissions(),
            "venue_123",
        )

    assert (
        error.value.status_code
        == 403
    )

def test_future_event_is_allowed():
    now = datetime(
        2026,
        10,
        1,
        12,
        tzinfo=timezone.utc,
    )

    starts_at = datetime(
        2026,
        10,
        2,
        20,
        tzinfo=timezone.utc,
    )

    validate_event_is_future(
        starts_at,
        now=now,
    )


def test_past_event_is_rejected():
    now = datetime(
        2026,
        10,
        2,
        12,
        tzinfo=timezone.utc,
    )

    starts_at = datetime(
        2026,
        10,
        1,
        20,
        tzinfo=timezone.utc,
    )

    with pytest.raises(
        HTTPException
    ) as error:
        validate_event_is_future(
            starts_at,
            now=now,
        )

    assert (
        error.value.status_code
        == 400
    )

def test_event_visibility_uses_explicit_end_time():
    start = datetime(
        2026,
        10,
        2,
        20,
        tzinfo=timezone.utc,
    )

    end = datetime(
        2026,
        10,
        3,
        2,
        tzinfo=timezone.utc,
    )

    result = event_visibility_end(
        starts_at=start,
        ends_at=end,
    )

    assert result == end


def test_event_without_end_remains_visible_for_eight_hours():
    start = datetime(
        2026,
        10,
        2,
        20,
        tzinfo=timezone.utc,
    )

    result = event_visibility_end(
        starts_at=start,
        ends_at=None,
    )

    assert result == (
        start
        + timedelta(
            hours=8
        )
    )

def test_event_creator_can_cancel():
    assert (
        can_cancel_event_with_context(
            actor_uid="user_123",
            organizer_uid="user_123",
            is_super_admin=False,
            manages_venue=False,
        )
        is True
    )


def test_super_admin_can_cancel_any_event():
    assert (
        can_cancel_event_with_context(
            actor_uid="admin_123",
            organizer_uid="user_123",
            is_super_admin=True,
            manages_venue=False,
        )
        is True
    )


def test_venue_manager_can_cancel_venue_event():
    assert (
        can_cancel_event_with_context(
            actor_uid="manager_123",
            organizer_uid="promoter_123",
            is_super_admin=False,
            manages_venue=True,
        )
        is True
    )


def test_unrelated_user_cannot_cancel_event():
    assert (
        can_cancel_event_with_context(
            actor_uid="random_123",
            organizer_uid="promoter_123",
            is_super_admin=False,
            manages_venue=False,
        )
        is False
    )


def test_only_pending_or_published_events_are_cancellable():
    assert (
        is_event_status_cancellable(
            "pending"
        )
        is True
    )

    assert (
        is_event_status_cancellable(
            "published"
        )
        is True
    )

    assert (
        is_event_status_cancellable(
            "cancelled"
        )
        is False
    )

    assert (
        is_event_status_cancellable(
            "rejected"
        )
        is False
    )

def test_super_admin_can_review_any_venue():
    assert (
        can_review_event_with_context(
            is_super_admin=True,
            managed_venue_ids=[],
            venue_id="venue_123",
        )
        is True
    )


def test_venue_manager_can_review_managed_venue():
    assert (
        can_review_event_with_context(
            is_super_admin=False,
            managed_venue_ids=[
                "venue_123",
            ],
            venue_id="venue_123",
        )
        is True
    )


def test_venue_manager_cannot_review_other_venue():
    assert (
        can_review_event_with_context(
            is_super_admin=False,
            managed_venue_ids=[
                "venue_123",
            ],
            venue_id="venue_other",
        )
        is False
    )


def test_only_pending_event_is_awaiting_approval():
    assert (
        is_event_pending_approval(
            "pending"
        )
        is True
    )

    assert (
        is_event_pending_approval(
            "published"
        )
        is False
    )

    assert (
        is_event_pending_approval(
            "rejected"
        )
        is False
    )

    assert (
        is_event_pending_approval(
            "cancelled"
        )
        is False
    )