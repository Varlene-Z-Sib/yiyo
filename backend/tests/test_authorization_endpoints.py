from fastapi import HTTPException

from app.services.authorization_service import (
    authorization_from_user,
    require_moderator,
    require_super_admin,
)


def test_permissions_for_regular_user():
    auth = authorization_from_user(
        {
            "uid": "user_123",
        }
    )

    assert (
        auth.app_role.value
        == "user"
    )

    assert (
        auth.is_moderator
        is False
    )

    assert (
        auth.is_super_admin
        is False
    )


def test_permissions_for_moderator():
    auth = authorization_from_user(
        {
            "uid": "moderator_123",
            "app_role": "moderator",
        }
    )

    assert (
        auth.app_role.value
        == "moderator"
    )

    assert (
        auth.is_moderator
        is True
    )

    assert (
        auth.is_super_admin
        is False
    )


def test_permissions_for_super_admin():
    auth = authorization_from_user(
        {
            "uid": "admin_123",
            "app_role": "super_admin",
        }
    )

    assert (
        auth.app_role.value
        == "super_admin"
    )

    assert (
        auth.is_moderator
        is True
    )

    assert (
        auth.is_super_admin
        is True
    )


def test_regular_user_cannot_access_moderation():
    try:
        require_moderator(
            {
                "uid": "user_123",
                "app_role": "user",
            }
        )

        assert False

    except HTTPException as error:
        assert (
            error.status_code
            == 403
        )


def test_moderator_cannot_access_super_admin():
    try:
        require_super_admin(
            {
                "uid": "moderator_123",
                "app_role": "moderator",
            }
        )

        assert False

    except HTTPException as error:
        assert (
            error.status_code
            == 403
        )