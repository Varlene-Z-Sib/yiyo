import os
from datetime import datetime, timezone
from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.services.yiyo_logic import (
    count_recent_actions,
    should_auto_flag_report,
)


REPORTS_COLLECTION = "vibe_reports"
REPORT_FLAGS_COLLECTION = "report_flags"

AUTO_FLAG_THRESHOLD = 3

# Contribution limits
SAME_VENUE_COOLDOWN_SECONDS = int(
    os.getenv(
        "REPORT_SAME_VENUE_COOLDOWN_SECONDS",
        str(30 * 60),
    )
)

CONTRIBUTION_HOURLY_LIMIT = int(
    os.getenv(
        "REPORT_HOURLY_LIMIT",
        "4",
    )
)

CONTRIBUTION_DAILY_LIMIT = int(
    os.getenv(
        "REPORT_DAILY_LIMIT",
        "12",
    )
)

FLAG_HOURLY_LIMIT = int(
    os.getenv(
        "FLAG_HOURLY_LIMIT",
        "2",
    )
)

FLAG_DAILY_LIMIT = int(
    os.getenv(
        "FLAG_DAILY_LIMIT",
        "5",
    )
)

# Flagging limits
FLAG_HOURLY_LIMIT = 2
FLAG_DAILY_LIMIT = 5


def _now_unix() -> int:
    return int(
        datetime.now(timezone.utc).timestamp()
    )


def _get_recent_user_report_timestamps(
    uid: str,
) -> list[int]:
    """
    Fetch only enough recent reports to evaluate the daily limit.

    We never need more than CONTRIBUTION_DAILY_LIMIT records here.
    """

    docs = (
        db.collection(REPORTS_COLLECTION)
        .where(
            filter=FieldFilter(
                "uid",
                "==",
                uid,
            )
        )
        .order_by(
            "created_at_unix",
            direction="DESCENDING",
        )
        .limit(CONTRIBUTION_DAILY_LIMIT)
        .stream()
    )

    timestamps = []

    for doc in docs:
        data = doc.to_dict() or {}

        created_at_unix = int(
            data.get(
                "created_at_unix",
                0,
            )
            or 0
        )

        if created_at_unix:
            timestamps.append(
                created_at_unix
            )

    return timestamps


def _get_recent_user_flag_timestamps(
    uid: str,
) -> list[int]:
    """
    Fetch only enough flags to evaluate the daily flagging limit.
    """

    docs = (
        db.collection(REPORT_FLAGS_COLLECTION)
        .where(
            filter=FieldFilter(
                "flagged_by_uid",
                "==",
                uid,
            )
        )
        .order_by(
            "created_at_unix",
            direction="DESCENDING",
        )
        .limit(FLAG_DAILY_LIMIT)
        .stream()
    )

    timestamps = []

    for doc in docs:
        data = doc.to_dict() or {}

        created_at_unix = int(
            data.get(
                "created_at_unix",
                0,
            )
            or 0
        )

        if created_at_unix:
            timestamps.append(
                created_at_unix
            )

    return timestamps


def enforce_contribution_rate_limits(
    uid: str,
    venue_id: str,
):
    """
    Protect contribution creation from spam.

    Rules:
    - Same venue: once every 30 minutes.
    - Any venues: maximum 4 reports per hour.
    - Any venues: maximum 12 reports per 24 hours.
    """

    now_unix = _now_unix()

    # ---------------------------------------------------------
    # Same-venue cooldown
    # ---------------------------------------------------------

    latest_docs = (
        db.collection(REPORTS_COLLECTION)
        .where(
            filter=FieldFilter(
                "uid",
                "==",
                uid,
            )
        )
        .where(
            filter=FieldFilter(
                "venue_id",
                "==",
                venue_id,
            )
        )
        .order_by(
            "created_at_unix",
            direction="DESCENDING",
        )
        .limit(1)
        .stream()
    )

    latest_doc = next(
        latest_docs,
        None,
    )

    if latest_doc is not None:
        latest = (
            latest_doc.to_dict()
            or {}
        )

        latest_unix = int(
            latest.get(
                "created_at_unix",
                0,
            )
            or 0
        )

        if latest_unix:
            elapsed = (
                now_unix
                - latest_unix
            )

            if elapsed < 0:
                elapsed = 0

            if (
                elapsed
                < SAME_VENUE_COOLDOWN_SECONDS
            ):
                remaining_seconds = (
                    SAME_VENUE_COOLDOWN_SECONDS
                    - elapsed
                )

                remaining_minutes = max(
                    1,
                    (
                        remaining_seconds
                        + 59
                    )
                    // 60,
                )

                raise HTTPException(
                    status_code=429,
                    detail=(
                        "You recently updated "
                        "this venue. Try again "
                        f"in about "
                        f"{remaining_minutes} "
                        "minute"
                        f"{'' if remaining_minutes == 1 else 's'}."
                    ),
                )

    # ---------------------------------------------------------
    # Global contribution limits
    # ---------------------------------------------------------

    timestamps = (
        _get_recent_user_report_timestamps(
            uid
        )
    )

    reports_last_hour = (
        count_recent_actions(
            timestamps,
            now_unix=now_unix,
            window_seconds=60 * 60,
        )
    )

    if (
        reports_last_hour
        >= CONTRIBUTION_HOURLY_LIMIT
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached the hourly "
                "contribution limit. "
                "Try again later."
            ),
        )

    reports_last_day = (
        count_recent_actions(
            timestamps,
            now_unix=now_unix,
            window_seconds=24 * 60 * 60,
        )
    )

    if (
        reports_last_day
        >= CONTRIBUTION_DAILY_LIMIT
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached today's "
                "contribution limit. "
                "Try again tomorrow."
            ),
        )


def enforce_flag_rate_limits(
    uid: str,
):
    """
    Protect report flagging from mass-report abuse.

    Rules:
    - Maximum 2 flags per hour.
    - Maximum 5 flags per 24 hours.

    One-flag-per-report is enforced separately.
    """

    now_unix = _now_unix()

    timestamps = (
        _get_recent_user_flag_timestamps(
            uid
        )
    )

    flags_last_hour = (
        count_recent_actions(
            timestamps,
            now_unix=now_unix,
            window_seconds=60 * 60,
        )
    )

    if flags_last_hour >= FLAG_HOURLY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached the hourly "
                "reporting limit. "
                "Try again later."
            ),
        )

    flags_last_day = (
        count_recent_actions(
            timestamps,
            now_unix=now_unix,
            window_seconds=24 * 60 * 60,
        )
    )

    if flags_last_day >= FLAG_DAILY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached today's "
                "reporting limit."
            ),
        )


def flag_report_for_moderation(
    report_id: str,
    uid: str,
    reason: str,
    details: str,
) -> dict:
    report_ref = (
        db.collection(REPORTS_COLLECTION)
        .document(report_id)
    )

    report_snapshot = (
        report_ref.get()
    )

    if not report_snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Report not found",
        )

    report = (
        report_snapshot.to_dict()
        or {}
    )

    report_owner_uid = str(
        report.get(
            "uid",
            "",
        )
    ).strip()

    if report_owner_uid == uid:
        raise HTTPException(
            status_code=400,
            detail=(
                "You cannot flag "
                "your own report"
            ),
        )

    current_status = str(
        report.get(
            "status",
            "active",
        )
    ).strip().lower()

    if current_status == "removed":
        raise HTTPException(
            status_code=409,
            detail=(
                "Report has already "
                "been removed"
            ),
        )

    if current_status == "flagged":
        return {
            "message":
                "Report is already "
                "under moderation",
            "report_id":
                report_id,
            "status":
                "flagged",
            "flag_count":
                int(
                    report.get(
                        "flag_count",
                        0,
                    )
                    or 0
                ),
        }

    # One deterministic flag document
    # per report/account pair.
    flag_document_id = (
        f"{report_id}__{uid}"
    )

    flag_ref = (
        db.collection(
            REPORT_FLAGS_COLLECTION
        )
        .document(
            flag_document_id
        )
    )

    if flag_ref.get().exists:
        raise HTTPException(
            status_code=409,
            detail=(
                "You have already "
                "flagged this report"
            ),
        )

    # Only enforce account-wide flagging limits
    # after confirming this isn't a duplicate.
    enforce_flag_rate_limits(
        uid
    )

    now = datetime.now(
        timezone.utc
    )

    flag_ref.set(
        {
            "report_id":
                report_id,

            "venue_id":
                report.get(
                    "venue_id",
                    "",
                ),

            "flagged_by_uid":
                uid,

            "reason":
                reason,

            "details":
                details,

            "created_at":
                now.isoformat(),

            "created_at_unix":
                int(
                    now.timestamp()
                ),
        }
    )

    # We only care whether the threshold has
    # been reached, so reading more than 3 flags
    # is unnecessary.
    flag_docs = (
        db.collection(
            REPORT_FLAGS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "report_id",
                "==",
                report_id,
            )
        )
        .limit(
            AUTO_FLAG_THRESHOLD
        )
        .stream()
    )

    flag_count = sum(
        1
        for _ in flag_docs
    )

    new_status = "active"

    update_data = {
        "flag_count":
            flag_count,
    }

    if should_auto_flag_report(
        flag_count,
        AUTO_FLAG_THRESHOLD,
    ):
        new_status = "flagged"

        update_data.update(
            {
                "status":
                    "flagged",

                "flagged_at":
                    now.isoformat(),

                "flagged_at_unix":
                    int(
                        now.timestamp()
                    ),
            }
        )

    report_ref.set(
        update_data,
        merge=True,
    )

    return {
        "message":
            (
                "Report flagged for review"
                if new_status == "flagged"
                else "Flag recorded"
            ),

        "report_id":
            report_id,

        "status":
            new_status,

        "flag_count":
            flag_count,
    }