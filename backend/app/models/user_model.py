from pydantic import BaseModel, ConfigDict


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    uid: str
    email: str = ""
    display_name: str = ""

    report_count: int = 0
    contributor_level: str = "Rookie"

    created_at: str | None = None


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

    # Private profile history is allowed to expose the user's
    # moderation state for their own contribution.
    status: str = "active"