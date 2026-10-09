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

class EventUpdate(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    title: str | None = Field(
        default=None,
        min_length=2,
        max_length=120,
    )

    description: str | None = Field(
        default=None,
        max_length=2000,
    )

    starts_at: datetime | None = None

    # None may intentionally clear
    # the existing end time.
    ends_at: datetime | None = None

    poster_url: str | None = Field(
        default=None,
        max_length=2048,
    )

    ticket_url: str | None = Field(
        default=None,
        max_length=2048,
    )

    tags: list[str] | None = Field(
        default=None,
        max_length=8,
    )

    @model_validator(
        mode="after"
    )
    def validate_update(
        self,
    ):
        fields = self.model_fields_set

        if not fields:
            raise ValueError(
                "At least one event field "
                "must be updated"
            )

        if (
            "title" in fields
            and self.title is None
        ):
            raise ValueError(
                "title cannot be null"
            )

        if (
            "description" in fields
            and self.description is None
        ):
            raise ValueError(
                "description cannot be null"
            )

        if (
            "starts_at" in fields
            and self.starts_at is None
        ):
            raise ValueError(
                "starts_at cannot be null"
            )

        if (
            "tags" in fields
            and self.tags is None
        ):
            raise ValueError(
                "tags cannot be null"
            )

        if (
            self.starts_at is not None
            and self.starts_at.tzinfo
            is None
        ):
            raise ValueError(
                "starts_at must include "
                "a timezone"
            )

        if (
            self.ends_at is not None
            and self.ends_at.tzinfo
            is None
        ):
            raise ValueError(
                "ends_at must include "
                "a timezone"
            )

        if (
            self.starts_at is not None
            and self.ends_at is not None
            and self.ends_at
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

    updated_at: str | None = None
    updated_at_unix: int | None = None
    updated_by_uid: str | None = None

    approved_by_uid: str | None = None

    cancelled_at: str | None = None
    cancelled_at_unix: int | None = None
    cancelled_by_uid: str | None = None

    organizer_deleted: bool = False

    tags: list[str] = Field(
        default_factory=list
    )

    hype_count: int = 0
    going_count: int = 0

    created_at: str
    created_at_unix: int

    published_at: str | None = None
    published_at_unix: int | None = None

class EventApprovalResponse(
    EventResponse
):
    organizer_username: str = ""
    organizer_full_name: str = ""
    organizer_email: str = ""