from enum import StrEnum

from pydantic import (
    BaseModel,
    ConfigDict,
)


class EventReactionType(StrEnum):
    HYPE = "hype"
    GOING = "going"


class EventReactionResult(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    event_id: str
    reaction: EventReactionType

    active: bool
    count: int


class EventEngagementState(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    event_id: str

    hype_count: int = 0
    going_count: int = 0

    hyped_by_me: bool = False
    going_by_me: bool = False