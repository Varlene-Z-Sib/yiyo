from datetime import datetime, timezone
import hashlib

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db


EVENTS_COLLECTION = "events"

EVENT_FLAGS_COLLECTION = (
    "event_flags"
)

EVENT_FLAG_HOURLY_LIMIT = 10
EVENT_FLAG_DAILY_LIMIT = 30


def _now_unix() -> int:
    return int(
        datetime.now(
            timezone.utc
        ).timestamp()
    )


def _event_flag_id(
    event_id: str,
    uid: str,
) -> str:
    raw = (
        f"{event_id}:"
        f"{uid}"
    )

    return hashlib.sha256(
        raw.encode("utf-8")
    ).hexdigest()


def _recent_flag_timestamps(
    uid: str,
) -> list[int]:
    docs = (
        db.collection(
            EVENT_FLAGS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "flagged_by_uid",
                "==",
                uid,
            )
        )
        .stream()
    )

    timestamps: list[int] = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        try:
            created_at_unix = int(
                data.get(
                    "created_at_unix",
                    0,
                )
                or 0
            )
        except (
            TypeError,
            ValueError,
        ):
            created_at_unix = 0

        if created_at_unix > 0:
            timestamps.append(
                created_at_unix
            )

    return timestamps


def _enforce_event_flag_limits(
    uid: str,
) -> None:
    now_unix = _now_unix()

    timestamps = (
        _recent_flag_timestamps(
            uid
        )
    )

    hour_count = sum(
        1
        for timestamp in timestamps
        if (
            now_unix -
            timestamp
        )
        <= 60 * 60
    )

    if (
        hour_count >=
        EVENT_FLAG_HOURLY_LIMIT
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "You've submitted several "
                "reports recently. Try "
                "again later."
            ),
        )

    day_count = sum(
        1
        for timestamp in timestamps
        if (
            now_unix -
            timestamp
        )
        <= 24 * 60 * 60
    )

    if (
        day_count >=
        EVENT_FLAG_DAILY_LIMIT
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "You've reached today's "
                "event report limit. "
                "Try again tomorrow."
            ),
        )


def flag_event_for_moderation(
    *,
    event_id: str,
    uid: str,
    reason: str,
    details: str,
) -> dict:
    event_ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = (
        event_ref.get()
    )

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    event = (
        snapshot.to_dict()
        or {}
    )

    organizer_uid = str(
        event.get(
            "organizer_uid",
            "",
        )
        or ""
    ).strip()

    if (
        organizer_uid ==
        uid
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "You cannot report "
                "your own event."
            ),
        )

    flag_ref = (
        db.collection(
            EVENT_FLAGS_COLLECTION
        )
        .document(
            _event_flag_id(
                event_id,
                uid,
            )
        )
    )

    if flag_ref.get().exists:
        raise HTTPException(
            status_code=409,
            detail=(
                "You've already reported "
                "this event."
            ),
        )

    _enforce_event_flag_limits(
        uid
    )

    now = datetime.now(
        timezone.utc
    )

    flag_ref.set(
        {
            "event_id":
                event_id,

            "flagged_by_uid":
                uid,

            "organizer_uid":
                organizer_uid,

            "reason":
                reason,

            "details":
                details.strip(),

            "created_at":
                now.isoformat(),

            "created_at_unix":
                int(
                    now.timestamp()
                ),

            "status":
                "open",
        }
    )

    event_ref.set(
        {
            "flag_count":
                int(
                    event.get(
                        "flag_count",
                        0,
                    )
                    or 0
                ) + 1,

            "last_flagged_at":
                now.isoformat(),

            "last_flagged_at_unix":
                int(
                    now.timestamp()
                ),
        },
        merge=True,
    )

    return {
        "message":
            "Event reported for review",

        "event_id":
            event_id,

        "status":
            "open",
    }