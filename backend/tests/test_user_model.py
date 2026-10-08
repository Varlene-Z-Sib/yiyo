from app.models.user_model import (
    UserContributionResponse,
    UserProfileResponse,
    UserProfileUpdate,
)


def test_user_profile_defaults():
    profile = UserProfileResponse(
        uid="user_123",
    )

    assert (
        profile.uid
        == "user_123"
    )

    assert profile.email == ""
    assert profile.username == ""
    assert profile.full_name == ""
    assert profile.display_name == ""

    assert (
        profile.profile_complete
        is False
    )

    assert profile.report_count == 0

    assert (
        profile.contributor_level
        == "Rookie"
    )

    assert profile.created_at is None


def test_user_profile_accepts_identity_and_stats():
    profile = UserProfileResponse(
        uid=
            "user_123",

        email=
            "test@example.com",

        username=
            "nightking",

        full_name=
            "Test User",

        display_name=
            "nightking",

        profile_complete=
            True,

        report_count=
            12,

        contributor_level=
            "Active",
    )

    assert (
        profile.username
        == "nightking"
    )

    assert (
        profile.full_name
        == "Test User"
    )

    assert (
        profile.profile_complete
        is True
    )

    assert profile.report_count == 12


def test_user_profile_update_accepts_identity():
    request = UserProfileUpdate(
        username=
            "nightking",

        full_name=
            "Test User",
    )

    assert (
        request.username
        == "nightking"
    )

    assert (
        request.full_name
        == "Test User"
    )


def test_user_contribution_defaults_to_active():
    report = UserContributionResponse(
        id=
            "report_123",

        venue_id=
            "venue_123",

        venue_name=
            "Test Lounge",
    )

    assert (
        report.status
        == "active"
    )

    assert (
        report.created_at_unix
        == 0
    )


def test_user_contribution_can_show_moderation_state():
    report = UserContributionResponse(
        id=
            "report_123",

        venue_id=
            "venue_123",

        venue_name=
            "Test Lounge",

        status=
            "flagged",
    )

    assert (
        report.status
        == "flagged"
    )