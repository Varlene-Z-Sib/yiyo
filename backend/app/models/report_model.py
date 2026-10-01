from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


CrowdLevel = Literal[
    "Dead",
    "Chill",
    "Busy",
    "Packed",
]

SafetyLevel = Literal[
    "Safe",
    "Okay",
    "Sketchy",
    "Unsafe",
]

MusicType = Literal[
    "Amapiano",
    "Afrobeat",
    "House",
    "Hip-hop",
    "Mixed",
]

QueueLength = Literal[
    "No queue",
    "Short",
    "Long",
]

YiyoStatus = Literal[
    "Yes definitely",
    "Kind of",
    "No",
]

ParkingAvailability = Literal[
    "Available",
    "Limited",
    "Full",
]

ParkingSafety = Literal[
    "Safe",
    "Okay",
    "Risky",
    "Unsafe",
]

ReportFlagReason = Literal[
    "false_information",
    "spam",
    "abusive_content",
    "safety_concern",
    "other",
]


class VibeReportCreate(BaseModel):
    """
    Quick Vibe contract.

    Minimum useful contribution:
    - venue
    - YIYO status
    - crowd level

    Everything else is optional enrichment.

    This avoids forcing users to invent information they
    do not know just to submit a useful real-time update.
    """

    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    venue_id: str = Field(
        min_length=1,
        max_length=256,
    )

    venue_name: str = Field(
        min_length=1,
        max_length=200,
    )

    # Quick Vibe required fields
    crowd_level: CrowdLevel
    yiyo_status: YiyoStatus

    # Optional detailed signals
    safety_level: SafetyLevel | None = None
    music_type: MusicType | None = None
    queue_length: QueueLength | None = None

    parking_availability: (
        ParkingAvailability | None
    ) = None

    parking_safety: (
        ParkingSafety | None
    ) = None

    parking_note: str = Field(
        default="",
        max_length=500,
    )

    comment: str = Field(
        default="",
        max_length=500,
    )

    # Kept for Flutter compatibility.
    # Server time remains authoritative.
    reported_at: str | None = Field(
        default=None,
        max_length=64,
    )


class ReportFlagCreate(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    reason: ReportFlagReason

    details: str = Field(
        default="",
        max_length=500,
    )