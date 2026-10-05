import pytest

from pydantic import ValidationError

import app.services.authorization_service as auth_service

from app.models.authorization_model import (
    BusinessMembership,
    MembershipGrantRequest,
    MembershipRole,
    MembershipStatus,
)


def _membership(
    *,
    membership_id: str,
    user_id: str = "user_123",
    role: MembershipRole,
    venue_id: str | None = None,
    status: MembershipStatus = (
        MembershipStatus.ACTIVE
    ),
):
    return BusinessMembership(
        id=membership_id,
        user_id=user_id,
        role=role,
        venue_id=venue_id,
        status=status,
    )


def test_promoter_membership_does_not_require_venue():
    membership = (
        MembershipGrantRequest(
            user_id="user_123",
            role=
                MembershipRole.PROMOTER,
        )
    )

    assert (
        membership.venue_id
        is None
    )


def test_promoter_membership_rejects_venue_id():
    with pytest.raises(
        ValidationError
    ):
        MembershipGrantRequest(
            user_id="user_123",
            role=
                MembershipRole.PROMOTER,
            venue_id="venue_123",
        )


def test_venue_manager_requires_venue_id():
    with pytest.raises(
        ValidationError
    ):
        MembershipGrantRequest(
            user_id="user_123",
            role=
                MembershipRole
                .VENUE_MANAGER,
        )


def test_promoter_can_create_events(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [
            _membership(
                membership_id=
                    "membership_1",

                role=
                    MembershipRole
                    .PROMOTER,
            )
        ],
    )

    allowed = (
        auth_service
        .can_create_event(
            {
                "uid":
                    "user_123",

                "app_role":
                    "user",
            },

            "venue_123",
        )
    )

    assert allowed is True


def test_venue_manager_can_create_event_for_own_venue(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [
            _membership(
                membership_id=
                    "membership_1",

                role=
                    MembershipRole
                    .VENUE_MANAGER,

                venue_id=
                    "venue_123",
            )
        ],
    )

    assert (
        auth_service
        .can_create_event(
            {
                "uid":
                    "user_123",
            },
            "venue_123",
        )
        is True
    )

    assert (
        auth_service
        .can_create_event(
            {
                "uid":
                    "user_123",
            },
            "venue_other",
        )
        is False
    )


def test_venue_manager_only_manages_assigned_venue(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [
            _membership(
                membership_id=
                    "membership_1",

                role=
                    MembershipRole
                    .VENUE_MANAGER,

                venue_id=
                    "venue_123",
            )
        ],
    )

    assert (
        auth_service
        .can_manage_venue(
            {
                "uid":
                    "user_123",
            },
            "venue_123",
        )
        is True
    )

    assert (
        auth_service
        .can_manage_venue(
            {
                "uid":
                    "user_123",
            },
            "venue_other",
        )
        is False
    )


def test_suspended_membership_has_no_permissions(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [
            _membership(
                membership_id=
                    "membership_1",

                role=
                    MembershipRole
                    .PROMOTER,

                status=
                    MembershipStatus
                    .SUSPENDED,
            )
        ],
    )

    permissions = (
        auth_service
        .get_effective_permissions(
            {
                "uid":
                    "user_123",
            }
        )
    )

    assert (
        permissions.is_promoter
        is False
    )

    assert (
        permissions.create_events
        is False
    )


def test_effective_permissions_include_managed_venues(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [
            _membership(
                membership_id=
                    "membership_1",

                role=
                    MembershipRole
                    .VENUE_MANAGER,

                venue_id=
                    "venue_b",
            ),

            _membership(
                membership_id=
                    "membership_2",

                role=
                    MembershipRole
                    .VENUE_MANAGER,

                venue_id=
                    "venue_a",
            ),
        ],
    )

    permissions = (
        auth_service
        .get_effective_permissions(
            {
                "uid":
                    "user_123",
            }
        )
    )

    assert (
        permissions
        .managed_venue_ids
        == [
            "venue_a",
            "venue_b",
        ]
    )

    assert (
        permissions.manage_venues
        is True
    )

    assert (
        permissions.create_events
        is True
    )


def test_super_admin_bypasses_membership_requirement(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_service,
        "get_user_memberships",
        lambda uid: [],
    )

    assert (
        auth_service
        .can_create_event(
            {
                "uid":
                    "admin_123",

                "app_role":
                    "super_admin",
            },
            "venue_123",
        )
        is True
    )

    assert (
        auth_service
        .can_manage_venue(
            {
                "uid":
                    "admin_123",

                "app_role":
                    "super_admin",
            },
            "venue_123",
        )
        is True
    )