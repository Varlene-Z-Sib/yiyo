import pytest

from fastapi import HTTPException

from app.models.authorization_model import (
    AppRole,
)
from app.services.authorization_service import (
    authorization_from_user,
    require_moderator,
    require_super_admin,
)


def test_regular_user_defaults_to_user_role():
    auth = (
        authorization_from_user(
            {
                "uid": "user_123",
            }
        )
    )

    assert (
        auth.app_role
        == AppRole.USER
    )

    assert (
        auth.is_moderator
        is False
    )

    assert (
        auth.is_super_admin
        is False
    )


def test_moderator_has_moderator_access():
    auth = require_moderator(
        {
            "uid": "user_123",
            "app_role": "moderator",
        }
    )

    assert (
        auth.app_role
        == AppRole.MODERATOR
    )

    assert (
        auth.is_moderator
        is True
    )


def test_super_admin_has_moderator_access():
    auth = require_moderator(
        {
            "uid": "admin_123",
            "app_role": "super_admin",
        }
    )

    assert (
        auth.is_super_admin
        is True
    )


def test_regular_user_cannot_access_moderation():
    with pytest.raises(
        HTTPException
    ) as error:
        require_moderator(
            {
                "uid": "user_123",
                "app_role": "user",
            }
        )

    assert (
        error.value.status_code
        == 403
    )


def test_only_super_admin_gets_super_admin_access():
    auth = require_super_admin(
        {
            "uid": "admin_123",
            "app_role": "super_admin",
        }
    )

    assert (
        auth.is_super_admin
        is True
    )

    with pytest.raises(
        HTTPException
    ) as error:
        require_super_admin(
            {
                "uid": "mod_123",
                "app_role": "moderator",
            }
        )

    assert (
        error.value.status_code
        == 403
    )


def test_unknown_role_falls_back_to_user():
    auth = (
        authorization_from_user(
            {
                "uid": "user_123",
                "app_role": "something_weird",
            }
        )
    )

    assert (
        auth.app_role
        == AppRole.USER
    )


def test_missing_uid_is_unauthorized():
    with pytest.raises(
        HTTPException
    ) as error:
        authorization_from_user(
            {}
        )

    assert (
        error.value.status_code
        == 401
    )