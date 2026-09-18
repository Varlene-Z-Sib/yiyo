from datetime import datetime, timezone


CURRENT_VIBE_MAX_AGE_HOURS = 24


def location_key_for(lat: float, lng: float) -> str:
    return f"{round(lat, 2)}_{round(lng, 2)}"


def contributor_level_from_count(report_count: int) -> str:
    if report_count >= 50:
        return "Legend"

    if report_count >= 20:
        return "Scout"

    if report_count >= 5:
        return "Active"

    return "Rookie"


def is_report_active(report: dict) -> bool:
    """
    Determine whether a report should be publicly visible and allowed
    to influence YIYO's current-vibe calculations.

    Legacy reports do not have a status field, so they are treated as
    active for backwards compatibility.
    """

    status = report.get("status")

    if status is None:
        return True

    return str(status).strip().lower() == "active"


def get_yiyo_badge_from_reports(
    reports: list[dict],
    now: datetime | None = None,
) -> str:
    """
    Calculate the current YIYO badge using active community reports
    from the last 24 hours.

    Flagged or removed reports remain stored for moderation/audit
    purposes but do not influence the current venue state.

    Reports older than 24 hours remain historical records but do not
    influence the venue's current vibe.
    """

    if not reports:
        return "MID"

    current_time = now or datetime.now(timezone.utc)

    total_score = 0.0
    usable_report_count = 0

    for report in reports:
        if not is_report_active(report):
            continue

        created_at_unix = report.get(
            "created_at_unix",
            0,
        )

        if not created_at_unix:
            continue

        try:
            report_time = datetime.fromtimestamp(
                int(created_at_unix),
                tz=timezone.utc,
            )
        except (TypeError, ValueError, OverflowError):
            continue

        age_hours = (
            current_time - report_time
        ).total_seconds() / 3600

        # Future timestamps should not influence current vibe.
        if age_hours < 0:
            continue

        # Reports older than 24 hours are history only.
        if age_hours > CURRENT_VIBE_MAX_AGE_HOURS:
            continue

        usable_report_count += 1
        report_score = 0.0

        yiyo_status = str(
            report.get("yiyo_status", "")
        ).strip().lower()

        if yiyo_status == "yes definitely":
            report_score += 3

        elif yiyo_status == "kind of":
            report_score += 1

        elif yiyo_status == "no":
            report_score -= 3

        crowd_level = str(
            report.get("crowd_level", "")
        ).strip().lower()

        if crowd_level == "packed":
            report_score += 2

        elif crowd_level == "busy":
            report_score += 1

        elif crowd_level == "chill":
            report_score += 0

        elif crowd_level == "dead":
            report_score -= 2

        safety_level = str(
            report.get("safety_level", "")
        ).strip().lower()

        if safety_level == "safe":
            report_score += 2

        elif safety_level == "okay":
            report_score += 0

        elif safety_level == "sketchy":
            report_score -= 2

        elif safety_level == "unsafe":
            report_score -= 4

        if age_hours <= 3:
            weight = 1.0

        elif age_hours <= 12:
            weight = 0.7

        else:
            # Reports between 12 and 24 hours old.
            weight = 0.4

        total_score += report_score * weight

    if usable_report_count == 0:
        return "MID"

    if total_score >= 4:
        return "YIYO"

    if total_score <= -2:
        return "NOT YIYO"

    return "MID"


def is_cache_fresh(
    last_refreshed_at_unix: int | None,
    now_unix: int,
    ttl_seconds: int,
) -> bool:
    if not last_refreshed_at_unix:
        return False

    try:
        refreshed_at = int(
            last_refreshed_at_unix
        )
    except (TypeError, ValueError):
        return False

    age_seconds = now_unix - refreshed_at

    return 0 <= age_seconds < ttl_seconds

def should_auto_flag_report(
    flag_count: int,
    threshold: int = 3,
) -> bool:
    return flag_count >= threshold

def count_recent_actions(
    timestamps: list[int],
    now_unix: int,
    window_seconds: int,
) -> int:
    count = 0

    for timestamp in timestamps:
        try:
            value = int(timestamp)
        except (TypeError, ValueError):
            continue

        age = now_unix - value

        if 0 <= age < window_seconds:
            count += 1

    return count