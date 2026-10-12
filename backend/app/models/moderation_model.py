from enum import StrEnum

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


class ModerationDecision(StrEnum):
    KEEP = "keep"
    REMOVE = "remove"


class ModerationResolutionRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    decision: ModerationDecision

    note: str = Field(
        default="",
        max_length=1000,
    )