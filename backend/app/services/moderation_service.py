from datetime import (
    datetime,
    timezone,
)

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db

from app.models.moderation_model import (
    ModerationDecision,
)

from app.services.event_service import (
    cancel_event,
)

from app.services.materialized_vibe_service import (
    safe_rebuild_venue_community_summary,
)


REPORT_FLAGS_COLLECTION = (
    "report_flags"
)

REPORTS_COLLECTION = (
    "vibe_reports"
)

EVENT_FLAGS_COLLECTION = (
    "event_flags"
)

EVENTS_COLLECTION = (
    "events"
)


def _clean(
    value,
) -> str:
    return str(
        value or ""
    ).strip()


def _is_open_flag(
    data: dict,
) -> bool:
    status = (
        _clean(
            data.get(
                "status",
                "open",
            )
        ).lower()
    )

    # Older report_flags created before
    # moderation resolution existed have no
    # explicit status. Treat them as open.
    return status in {
        "",
        "open",
    }


def _flag_summary(
    flags: list[dict],
) -> dict:
    reasons: dict[str, int] = {}

    details: list[str] = []

    latest_unix = 0
    latest_at = ""

    for flag in flags:
        reason = (
            _clean(
                flag.get(
                    "reason",
                    "other",
                )
            )
            or "other"
        )

        reasons[reason] = (
            reasons.get(
                reason,
                0,
            )
            + 1
        )

        detail = _clean(
            flag.get(
                "details"
            )
        )

        if (
            detail
            and detail not in details
            and len(details) < 5
        ):
            details.append(
                detail
            )

        try:
            created_at_unix = int(
                flag.get(
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

        if (
            created_at_unix
            >= latest_unix
        ):
            latest_unix = (
                created_at_unix
            )

            latest_at = _clean(
                flag.get(
                    "created_at"
                )
            )

    return {
        "flag_count":
            len(flags),

        "reasons":
            reasons,

        "details":
            details,

        "latest_flagged_at":
            latest_at,

        "latest_flagged_at_unix":
            latest_unix,
    }


def _get_open_flags_grouped(
    *,
    collection_name: str,
    target_field: str,
) -> dict[str, list[dict]]:
    docs = (
        db.collection(
            collection_name
        )
        .stream()
    )

    grouped: dict[
        str,
        list[dict],
    ] = {}

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        if not _is_open_flag(
            data
        ):
            continue

        target_id = _clean(
            data.get(
                target_field
            )
        )

        if not target_id:
            continue

        grouped.setdefault(
            target_id,
            [],
        ).append(
            {
                **data,
                "id":
                    doc.id,
            }
        )

    return grouped


def _community_cases() -> list[dict]:
    grouped = (
        _get_open_flags_grouped(
            collection_name=
                REPORT_FLAGS_COLLECTION,

            target_field=
                "report_id",
        )
    )

    cases: list[dict] = []

    for (
        report_id,
        flags,
    ) in grouped.items():
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
            continue

        report = (
            snapshot.to_dict()
            or {}
        )

        summary = (
            _flag_summary(
                flags
            )
        )

        cases.append(
            {
                "type":
                    "community",

                "report_id":
                    report_id,

                "venue_id":
                    _clean(
                        report.get(
                            "venue_id"
                        )
                    ),

                "status":
                    _clean(
                        report.get(
                            "status",
                            "active",
                        )
                    )
                    or "active",

                "yiyo_status":
                    _clean(
                        report.get(
                            "yiyo_status"
                        )
                    ),

                "crowd_level":
                    _clean(
                        report.get(
                            "crowd_level"
                        )
                    ),

                "safety_level":
                    _clean(
                        report.get(
                            "safety_level"
                        )
                    ),

                "music_type":
                    _clean(
                        report.get(
                            "music_type"
                        )
                    ),

                "queue_length":
                    _clean(
                        report.get(
                            "queue_length"
                        )
                    ),

                "parking_availability":
                    _clean(
                        report.get(
                            "parking_availability"
                        )
                    ),

                "parking_safety":
                    _clean(
                        report.get(
                            "parking_safety"
                        )
                    ),

                "parking_note":
                    _clean(
                        report.get(
                            "parking_note"
                        )
                    ),

                "comment":
                    _clean(
                        report.get(
                            "comment"
                        )
                    ),

                "created_at":
                    _clean(
                        report.get(
                            "created_at"
                        )
                    ),

                "created_at_unix":
                    int(
                        report.get(
                            "created_at_unix",
                            0,
                        )
                        or 0
                    ),

                **summary,
            }
        )

    cases.sort(
        key=lambda item:
            item[
                "latest_flagged_at_unix"
            ],
        reverse=True,
    )

    return cases


def _event_cases() -> list[dict]:
    grouped = (
        _get_open_flags_grouped(
            collection_name=
                EVENT_FLAGS_COLLECTION,

            target_field=
                "event_id",
        )
    )

    cases: list[dict] = []

    for (
        event_id,
        flags,
    ) in grouped.items():
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
            continue

        event = (
            snapshot.to_dict()
            or {}
        )

        summary = (
            _flag_summary(
                flags
            )
        )

        cases.append(
            {
                "type":
                    "event",

                "event_id":
                    event_id,

                "title":
                    _clean(
                        event.get(
                            "title"
                        )
                    ),

                "description":
                    _clean(
                        event.get(
                            "description"
                        )
                    ),

                "venue_id":
                    _clean(
                        event.get(
                            "venue_id"
                        )
                    ),

                "venue_name":
                    _clean(
                        event.get(
                            "venue_name"
                        )
                    ),

                "status":
                    _clean(
                        event.get(
                            "status"
                        )
                    ),

                "starts_at":
                    _clean(
                        event.get(
                            "starts_at"
                        )
                    ),

                "starts_at_unix":
                    int(
                        event.get(
                            "starts_at_unix",
                            0,
                        )
                        or 0
                    ),

                "created_at":
                    _clean(
                        event.get(
                            "created_at"
                        )
                    ),

                "created_at_unix":
                    int(
                        event.get(
                            "created_at_unix",
                            0,
                        )
                        or 0
                    ),

                **summary,
            }
        )

    cases.sort(
        key=lambda item:
            item[
                "latest_flagged_at_unix"
            ],
        reverse=True,
    )

    return cases


def get_super_admin_moderation_queue(
) -> dict:
    community = (
        _community_cases()
    )

    events = (
        _event_cases()
    )

    return {
        "community":
            community,

        "events":
            events,

        "community_count":
            len(
                community
            ),

        "event_count":
            len(
                events
            ),

        "total_count":
            len(
                community
            )
            + len(
                events
            ),
    }


def _resolve_target_flags(
    *,
    collection_name: str,
    target_field: str,
    target_id: str,
    decision: ModerationDecision,
    reviewer_uid: str,
    note: str,
    now: datetime,
) -> int:
    docs = (
        db.collection(
            collection_name
        )
        .where(
            filter=FieldFilter(
                target_field,
                "==",
                target_id,
            )
        )
        .stream()
    )

    batch = db.batch()

    pending = 0
    resolved = 0

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        if not _is_open_flag(
            data
        ):
            continue

        batch.set(
            doc.reference,
            {
                "status":
                    "resolved",

                "resolution":
                    decision.value,

                "reviewed_by_uid":
                    reviewer_uid,

                "reviewed_at":
                    now.isoformat(),

                "reviewed_at_unix":
                    int(
                        now.timestamp()
                    ),

                "moderator_note":
                    note,
            },
            merge=True,
        )

        pending += 1
        resolved += 1

        if pending >= 400:
            batch.commit()

            batch = db.batch()

            pending = 0

    if pending > 0:
        batch.commit()

    return resolved


def resolve_community_report(
    *,
    report_id: str,
    decision: ModerationDecision,
    reviewer_uid: str,
    note: str,
) -> dict:
    report_ref = (
        db.collection(
            REPORTS_COLLECTION
        )
        .document(
            report_id
        )
    )

    snapshot = (
        report_ref.get()
    )

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail=(
                "Community update "
                "not found"
            ),
        )

    report = (
        snapshot.to_dict()
        or {}
    )

    venue_id = _clean(
        report.get(
            "venue_id"
        )
    )

    now = datetime.now(
        timezone.utc
    )

    update = {
        "moderation_resolution":
            decision.value,

        "moderated_by_uid":
            reviewer_uid,

        "moderated_at":
            now.isoformat(),

        "moderated_at_unix":
            int(
                now.timestamp()
            ),

        "moderator_note":
            note,
    }

    if (
        decision
        == ModerationDecision.KEEP
    ):
        update.update(
            {
                "status":
                    "active",

                "flag_count":
                    0,
            }
        )

    else:
        update.update(
            {
                "status":
                    "removed",

                "removed_at":
                    now.isoformat(),

                "removed_at_unix":
                    int(
                        now.timestamp()
                    ),

                "removed_by_uid":
                    reviewer_uid,
            }
        )

    report_ref.set(
        update,
        merge=True,
    )

    resolved_flags = (
        _resolve_target_flags(
            collection_name=
                REPORT_FLAGS_COLLECTION,

            target_field=
                "report_id",

            target_id=
                report_id,

            decision=
                decision,

            reviewer_uid=
                reviewer_uid,

            note=
                note,

            now=
                now,
        )
    )

    if venue_id:
        safe_rebuild_venue_community_summary(
            venue_id
        )

    return {
        "report_id":
            report_id,

        "decision":
            decision.value,

        "resolved_flags":
            resolved_flags,

        "status":
            update["status"],
    }


def resolve_event_report(
    *,
    event_id: str,
    decision: ModerationDecision,
    reviewer_uid: str,
    note: str,
    current_user: dict,
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

    now = datetime.now(
        timezone.utc
    )

    if (
        decision
        == ModerationDecision.REMOVE
    ):
        event = cancel_event(
            event_id,
            current_user,
        )

        resulting_status = (
            event.status.value
        )

    else:
        resulting_status = _clean(
            (
                snapshot.to_dict()
                or {}
            ).get(
                "status"
            )
        )

    event_ref.set(
        {
            "flag_count":
                0,

            "moderation_resolution":
                decision.value,

            "moderated_by_uid":
                reviewer_uid,

            "moderated_at":
                now.isoformat(),

            "moderated_at_unix":
                int(
                    now.timestamp()
                ),

            "moderator_note":
                note,
        },
        merge=True,
    )

    resolved_flags = (
        _resolve_target_flags(
            collection_name=
                EVENT_FLAGS_COLLECTION,

            target_field=
                "event_id",

            target_id=
                event_id,

            decision=
                decision,

            reviewer_uid=
                reviewer_uid,

            note=
                note,

            now=
                now,
        )
    )

    return {
        "event_id":
            event_id,

        "decision":
            decision.value,

        "resolved_flags":
            resolved_flags,

        "status":
            resulting_status,
    }