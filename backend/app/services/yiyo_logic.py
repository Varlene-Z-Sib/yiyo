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


def get_yiyo_badge_from_reports(
    reports: list[dict],
    now: datetime | None = None,
) -> str:
    """
    Calculate the current YIYO badge from recent community reports.

    Reports older than 24 hours remain historical records but do not
    influence the venue's current vibe.
    """

    if not reports:
        return "MID"

    current_time = now or datetime.now(timezone.utc)

    total_score = 0.0
    usable_report_count = 0

    for report in reports:
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

        # Ignore timestamps that appear to come from the future.
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

    # There may be historical reports in Firestore, but if none of them
    # are within the current 24-hour window the venue is MID.
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