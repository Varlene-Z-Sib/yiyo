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
    response_count=sum(
        counts.values()
    ),
)
SAFETY_PULSE_MAX_AGE_HOURS = 8


def _recent_safety_reports(
    reports: list[dict],
    now: datetime,
) -> list[dict]:
    """
    Safety should expire faster than the
    general 24-hour Current Vibe.

    Only reports from the last 8 hours
    that actually contain a safety answer
    contribute to Safety Pulse.
    """

    safety_reports = []

    for report in reports:
        raw_value = str(
            report.get(
                "safety_level",
                "",
            )
            or ""
        ).strip()

        if not raw_value:
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
            > SAFETY_PULSE_MAX_AGE_HOURS
        ):
            continue

        safety_reports.append(
            report
        )

    safety_reports.sort(
        key=lambda report: (
            _valid_created_at_unix(
                report
            )
            or 0
        ),
        reverse=True,
    )

    return safety_reports


def _safety_pulse(
    reports: list[dict],
) -> VibeSignalSummary:
    """
    Convert the older stored safety values
    into the simpler user-facing pulse.

    This means old reports remain useful:
      Safe       -> Comfortable
      Okay       -> Stay alert
      Sketchy    -> Stay alert
      Unsafe     -> I feel unsafe
    """

    mapping = {
        "safe":
            "Comfortable",

        "okay":
            "Stay alert",

        "sketchy":
            "Stay alert",

        "unsafe":
            "I feel unsafe",
    }

    normalized_reports = []

    for report in reports:
        raw_value = str(
            report.get(
                "safety_level",
                "",
            )
            or ""
        ).strip()

        mapped = mapping.get(
            raw_value.casefold()
        )

        if mapped is None:
            continue

        normalized_reports.append(
            {
                "safety_pulse":
                    mapped,
            }
        )

    return _consensus_value(
        normalized_reports,
        "safety_pulse",
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

    safety_reports = (
        _recent_safety_reports(
            current_reports,
            current_time,
        )
    )

    latest_created_at_unix = None
    safety_latest_created_at_unix = None

    if current_reports:
        latest_created_at_unix = (
            _valid_created_at_unix(
                current_reports[0]
            )
        )

    if safety_reports:
        safety_latest_created_at_unix = (
            _valid_created_at_unix(
                safety_reports[0]
            )
        )

    return CurrentVibeSummaryResponse(
        report_count=len(
            current_reports
        ),

        latest_created_at_unix=(
            latest_created_at_unix
        ),

        safety_latest_created_at_unix=(
            safety_latest_created_at_unix
        ),

        crowd=_consensus_value(
            current_reports,
            "crowd_level",
        ),

        safety=_safety_pulse(
            safety_reports,
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
