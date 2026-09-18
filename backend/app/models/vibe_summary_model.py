from pydantic import BaseModel, Field


class VibeSignalSummary(BaseModel):
    value: str | None = None
    agreement_count: int = 0


class CurrentVibeSummaryResponse(BaseModel):
    report_count: int = 0

    latest_created_at_unix: int | None = None

    crowd: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )

    safety: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )

    music: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )

    queue: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )

    parking_availability: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )

    parking_safety: VibeSignalSummary = Field(
        default_factory=VibeSignalSummary
    )