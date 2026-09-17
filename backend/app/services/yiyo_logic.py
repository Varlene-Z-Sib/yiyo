from datetime import datetime, timezone


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


def get_yiyo_badge_from_reports(reports: list[dict]) -> str:
    if not reports:
        return "MID"

    total_score = 0.0
    now = datetime.now(timezone.utc)

    for report in reports:
        report_score = 0.0

        yiyo_status = str(report.get("yiyo_status", "")).strip().lower()
        if yiyo_status == "yes definitely":
            report_score += 3
        elif yiyo_status == "kind of":
            report_score += 1
        elif yiyo_status == "no":
            report_score -= 3

        crowd_level = str(report.get("crowd_level", "")).strip().lower()
        if crowd_level == "packed":
            report_score += 2
        elif crowd_level == "busy":
            report_score += 1
        elif crowd_level == "chill":
            report_score += 0
        elif crowd_level == "dead":
            report_score -= 2

        safety_level = str(report.get("safety_level", "")).strip().lower()
        if safety_level == "safe":
            report_score += 2
        elif safety_level == "okay":
            report_score += 0
        elif safety_level == "sketchy":
            report_score -= 2
        elif safety_level == "unsafe":
            report_score -= 4

        created_at_unix = report.get("created_at_unix", 0)
        age_hours = 999.0

        if created_at_unix:
            report_time = datetime.fromtimestamp(
                created_at_unix,
                tz=timezone.utc,
            )
            age_hours = (now - report_time).total_seconds() / 3600

        if age_hours <= 3:
            weight = 1.0
        elif age_hours <= 12:
            weight = 0.7
        else:
            weight = 0.4

        total_score += report_score * weight

    if total_score >= 4:
        return "YIYO"
    elif total_score <= -2:
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
        refreshed_at = int(last_refreshed_at_unix)
    except (TypeError, ValueError):
        return False

    age_seconds = now_unix - refreshed_at

    return 0 <= age_seconds < ttl_seconds