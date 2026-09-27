import os
from datetime import datetime, timezone

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.services.materialized_vibe_service import (
    safe_rebuild_venue_community_summary,
)
from app.services.yiyo_logic import (
    count_recent_actions,
    should_auto_flag_report,
)


REPORTS_COLLECTION = "vibe_reports"
REPORT_FLAGS_COLLECTION = "report_flags"

AUTO_FLAG_THRESHOLD = 3


# ---------------------------------------------------------------------------
# Contribution limits
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Flag limits
# ---------------------------------------------------------------------------

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


def _now_unix() -> int:
    return int(
        datetime.now(
            timezone.utc
        ).timestamp()
    )


# ---------------------------------------------------------------------------
# Contribution rate limiting
# ---------------------------------------------------------------------------

def _get_recent_user_report_timestamps(
    uid: str,
) -> list[int]:
    docs = (
        db.collection(
            REPORTS_COLLECTION
        )
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
        .limit(
            CONTRIBUTION_DAILY_LIMIT
        )
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
    Rules:

    - Same venue:
      one contribution per configured cooldown.

    - All venues:
      configured hourly limit.

    - All venues:
      configured daily limit.
    """

    now_unix = _now_unix()

    latest_docs = (
        db.collection(
            REPORTS_COLLECTION
        )
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


# ---------------------------------------------------------------------------
# Flag rate limiting
# ---------------------------------------------------------------------------

def _get_recent_user_flag_timestamps(
    uid: str,
) -> list[int]:
    docs = (
        db.collection(
            REPORT_FLAGS_COLLECTION
        )
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
        .limit(
            FLAG_DAILY_LIMIT
        )
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


def enforce_flag_rate_limits(
    uid: str,
):
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

    if (
        flags_last_hour
        >= FLAG_HOURLY_LIMIT
    ):
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

    if (
        flags_last_day
        >= FLAG_DAILY_LIMIT
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached today's "
                "reporting limit."
            ),
        )


# ---------------------------------------------------------------------------
# Report moderation
# ---------------------------------------------------------------------------

def flag_report_for_moderation(
    report_id: str,
    uid: str,
    reason: str,
    details: str,
) -> dict:
    report_ref = (
        db.collection(
            REPORTS_COLLECTION
        )
        .document(
            report_id
        )
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

    venue_id = str(
        report.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    report_owner_uid = str(
        report.get(
            "uid",
            "",
        )
        or ""
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
        or "active"
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
                venue_id,

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

    # Only a moderation-state change affects Current Vibe.
    #
    # 1 or 2 flags leave the report active, so there is no reason
    # to rebuild the venue summary yet.
    if (
        new_status == "flagged"
        and venue_id
    ):
        safe_rebuild_venue_community_summary(
            venue_id
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