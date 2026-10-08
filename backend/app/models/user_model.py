from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    uid: str
    email: str = ""

    # New YIYO identity fields.
    username: str = ""
    full_name: str = ""

    # Kept temporarily for backward
    # compatibility with existing clients/data.
    display_name: str = ""

    profile_complete: bool = False

    report_count: int = 0
    contributor_level: str = "Rookie"

    created_at: str | None = None


class UserProfileUpdate(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    username: str = Field(
        min_length=3,
        max_length=24,
    )

    full_name: str = Field(
        default="",
        max_length=80,
    )


class UserContributionResponse(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    id: str

    venue_id: str
    venue_name: str

    crowd_level: str = ""
    safety_level: str = ""
    music_type: str = ""
    queue_length: str = ""
    yiyo_status: str = ""

    parking_availability: str = ""
    parking_safety: str = ""
    parking_note: str = ""

    comment: str = ""

    reported_at: str = ""
    created_at_unix: int = 0

    # Private profile history is allowed
    # to expose the user's moderation state.
    status: str = "active"