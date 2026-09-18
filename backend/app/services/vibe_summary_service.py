from datetime import datetime, timezone

from app.models.vibe_summary_model import (
    CurrentVibeSummaryResponse,
    VibeSignalSummary,
)
from app.services.yiyo_logic import (
    CURRENT_VIBE_MAX_AGE_HOURS,
    is_report_active,
)


def _valid_created_at_unix(
    report: dict,
) -> int | None:
    value = report.get(
        "created_at_unix",
        0,
    )

    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None

    if parsed <= 0:
        return None

    return parsed


def _get_current_reports(
    reports: list[dict],
    now: datetime,
) -> list[dict]:
    current_reports = []

    for report in reports:
        if not is_report_active(report):
            continue

        created_at_unix = (
            _valid_created_at_unix(
                report
            )
        )

        if created_at_unix is None:
            continue

        try:
            report_time = (
                datetime.fromtimestamp(
                    created_at_unix,
                    tz=timezone.utc,
                )
            )
        except (
            ValueError,
            OverflowError,
            OSError,
        ):
            continue

        age_hours = (
            now - report_time
        ).total_seconds() / 3600

        if age_hours < 0:
            continue

        if (
            age_hours
            > CURRENT_VIBE_MAX_AGE_HOURS
        ):
            continue

        current_reports.append(
            report
        )

    current_reports.sort(
        key=lambda report: (
            _valid_created_at_unix(
                report
            )
            or 0
        ),
        reverse=True,
    )

    return current_reports


def _consensus_value(
    reports: list[dict],
    field_name: str,
) -> VibeSignalSummary:
    """
    Choose the most common non-empty value.

    If two values have the same count, the value appearing in the
    newest report wins because reports are ordered newest-first.
    """

    counts: dict[str, int] = {}
    display_values: dict[str, str] = {}
    first_seen_index: dict[str, int] = {}

    for index, report in enumerate(
        reports
    ):
        raw_value = str(
            report.get(
                field_name,
                "",
            )
            or ""
        ).strip()

        if not raw_value:
            continue

        normalized = (
            raw_value.casefold()
        )

        counts[normalized] = (
            counts.get(
                normalized,
                0,
            )
            + 1
        )

        if normalized not in display_values:
            display_values[
                normalized
            ] = raw_value

            first_seen_index[
                normalized
            ] = index

    if not counts:
        return VibeSignalSummary()

    winner = max(
        counts,
        key=lambda value: (
            counts[value],
            -first_seen_index[value],
        ),
    )

    return VibeSignalSummary(
        value=display_values[winner],
        agreement_count=counts[winner],
    )


def build_current_vibe_summary(
    reports: list[dict],
    now: datetime | None = None,
) -> CurrentVibeSummaryResponse:
    current_time = (
        now
        or datetime.now(
            timezone.utc
        )
    )

    current_reports = (
        _get_current_reports(
            reports,
            current_time,
        )
    )

    latest_created_at_unix = None

    if current_reports:
        latest_created_at_unix = (
            _valid_created_at_unix(
                current_reports[0]
            )
        )

    return CurrentVibeSummaryResponse(
        report_count=len(
            current_reports
        ),

        latest_created_at_unix=(
            latest_created_at_unix
        ),

        crowd=_consensus_value(
            current_reports,
            "crowd_level",
        ),

        safety=_consensus_value(
            current_reports,
            "safety_level",
        ),

        music=_consensus_value(
            current_reports,
            "music_type",
        ),

        queue=_consensus_value(
            current_reports,
            "queue_length",
        ),

        parking_availability=(
            _consensus_value(
                current_reports,
                "parking_availability",
            )
        ),

        parking_safety=(
            _consensus_value(
                current_reports,
                "parking_safety",
            )
        ),
    )
