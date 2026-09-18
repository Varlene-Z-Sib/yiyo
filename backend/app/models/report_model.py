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

    crowd_level: CrowdLevel
    safety_level: SafetyLevel
    music_type: MusicType
    queue_length: QueueLength
    yiyo_status: YiyoStatus

    parking_availability: ParkingAvailability
    parking_safety: ParkingSafety

    parking_note: str = Field(
        default="",
        max_length=500,
    )

    comment: str = Field(
        default="",
        max_length=500,
    )

    # Kept for compatibility with Flutter.
    # The backend uses server time as authoritative.
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