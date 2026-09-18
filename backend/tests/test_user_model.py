from app.models.user_model import (
    UserContributionResponse,
    UserProfileResponse,
)


def test_user_profile_defaults():
    profile = UserProfileResponse(
        uid="user_123",
    )

    assert profile.uid == "user_123"
    assert profile.email == ""
    assert profile.display_name == ""
    assert profile.report_count == 0
    assert (
        profile.contributor_level
        == "Rookie"
    )
    assert profile.created_at is None


def test_user_profile_accepts_stats():
    profile = UserProfileResponse(
        uid="user_123",
        email="test@example.com",
        display_name="Test User",
        report_count=12,
        contributor_level="Active",
    )

    assert (
        profile.email
        == "test@example.com"
    )

    assert (
        profile.display_name
        == "Test User"
    )

    assert profile.report_count == 12

    assert (
        profile.contributor_level
        == "Active"
    )


def test_user_contribution_defaults_to_active():
    report = UserContributionResponse(
        id="report_123",
        venue_id="venue_123",
        venue_name="Test Lounge",
    )

    assert report.status == "active"

    assert (
        report.created_at_unix
        == 0
    )


def test_user_contribution_can_show_moderation_state():
    report = UserContributionResponse(
        id="report_123",
        venue_id="venue_123",
        venue_name="Test Lounge",
        status="flagged",
    )

    assert (
        report.status
        == "flagged"
    )