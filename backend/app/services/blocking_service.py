from datetime import datetime, timezone
import hashlib

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db


USER_BLOCKS_COLLECTION = "user_blocks"
REPORTS_COLLECTION = "vibe_reports"
EVENTS_COLLECTION = "events"


def _clean_uid(
    value,
) -> str:
    return str(
        value or ""
    ).strip()


def _block_document_id(
    blocker_uid: str,
    blocked_uid: str,
) -> str:
    raw = (
        f"{blocker_uid}:"
        f"{blocked_uid}"
    )

    return hashlib.sha256(
        raw.encode("utf-8")
    ).hexdigest()


def get_blocked_user_ids(
    blocker_uid: str,
) -> set[str]:
    blocker_uid = _clean_uid(
        blocker_uid
    )

    if not blocker_uid:
        return set()

    docs = (
        db.collection(
            USER_BLOCKS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "blocker_uid",
                "==",
                blocker_uid,
            )
        )
        .stream()
    )

    blocked: set[str] = set()

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        blocked_uid = (
            _clean_uid(
                data.get(
                    "blocked_uid"
                )
            )
        )

        if blocked_uid:
            blocked.add(
                blocked_uid
            )

    return blocked


def _store_block(
    *,
    blocker_uid: str,
    blocked_uid: str,
    source_type: str,
    source_id: str,
) -> dict:
    blocker_uid = _clean_uid(
        blocker_uid
    )

    blocked_uid = _clean_uid(
        blocked_uid
    )

    if not blocker_uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    if not blocked_uid:
        raise HTTPException(
            status_code=409,
            detail=(
                "This account is no longer "
                "available to block."
            ),
        )

    if (
        blocker_uid ==
        blocked_uid
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "You cannot block "
                "yourself."
            ),
        )

    doc_ref = (
        db.collection(
            USER_BLOCKS_COLLECTION
        )
        .document(
            _block_document_id(
                blocker_uid,
                blocked_uid,
            )
        )
    )

    existing = (
        doc_ref.get()
    )

    if existing.exists:
        return {
            "message":
                "User already blocked",

            "blocked":
                True,
        }

    now = datetime.now(
        timezone.utc
    )

    doc_ref.set(
        {
            "blocker_uid":
                blocker_uid,

            "blocked_uid":
                blocked_uid,

            "source_type":
                source_type,

            "source_id":
                source_id,

            "created_at":
                now.isoformat(),

            "created_at_unix":
                int(
                    now.timestamp()
                ),
        }
    )

    return {
        "message":
            "User blocked",

        "blocked":
            True,
    }


def block_report_contributor(
    *,
    report_id: str,
    blocker_uid: str,
) -> dict:
    snapshot = (
        db.collection(
            REPORTS_COLLECTION
        )
        .document(
            report_id
        )
        .get()
    )

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Report not found",
        )

    report = (
        snapshot.to_dict()
        or {}
    )

    return _store_block(
        blocker_uid=
            blocker_uid,

        blocked_uid=
            _clean_uid(
                report.get(
                    "uid"
                )
            ),

        source_type=
            "vibe_report",

        source_id=
            report_id,
    )


def block_event_organizer(
    *,
    event_id: str,
    blocker_uid: str,
) -> dict:
    snapshot = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
        .get()
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

    return _store_block(
        blocker_uid=
            blocker_uid,

        blocked_uid=
            _clean_uid(
                event.get(
                    "organizer_uid"
                )
            ),

        source_type=
            "event",

        source_id=
            event_id,
    )