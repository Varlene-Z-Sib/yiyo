from datetime import datetime
from enum import StrEnum

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)


class EventStatus(StrEnum):
    PENDING = "pending"
    PUBLISHED = "published"
    REJECTED = "rejected"
    CANCELLED = "cancelled"


class EventCreate(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    title: str = Field(
        min_length=2,
        max_length=120,
    )

    description: str = Field(
        default="",
        max_length=2000,
    )

    venue_id: str = Field(
        min_length=1,
        max_length=256,
    )

    starts_at: datetime

    ends_at: datetime | None = None

    poster_url: str | None = Field(
        default=None,
        max_length=2048,
    )

    ticket_url: str | None = Field(
        default=None,
        max_length=2048,
    )

    tags: list[str] = Field(
        default_factory=list,
        max_length=8,
    )

    @model_validator(
        mode="after"
    )
    def validate_event_times(
        self,
    ):
        if (
            self.starts_at.tzinfo
            is None
        ):
            raise ValueError(
                "starts_at must include "
                "a timezone"
            )

        if self.ends_at is not None:
            if (
                self.ends_at.tzinfo
                is None
            ):
                raise ValueError(
                    "ends_at must include "
                    "a timezone"
                )

            if (
                self.ends_at
                <= self.starts_at
            ):
                raise ValueError(
                    "ends_at must be after "
                    "starts_at"
                )

        return self


class EventResponse(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    id: str

    title: str
    description: str = ""

    venue_id: str
    venue_name: str

    venue_address: str = ""

    venue_lat: float | None = None
    venue_lng: float | None = None

    organizer_uid: str

    status: EventStatus

    starts_at: str
    starts_at_unix: int

    ends_at: str | None = None
    ends_at_unix: int | None = None

    poster_url: str | None = None
    ticket_url: str | None = None

    tags: list[str] = Field(
        default_factory=list
    )

    hype_count: int = 0
    going_count: int = 0

    created_at: str
    created_at_unix: int

    published_at: str | None = None
    published_at_unix: int | None = None