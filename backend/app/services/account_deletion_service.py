from collections import defaultdict
from datetime import (
    datetime,
    timezone,
)

from fastapi import HTTPException
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db

from app.models.event_model import (
    EventStatus,
)


USERS_COLLECTION = "users"
USERNAMES_COLLECTION = "usernames"

BUSINESS_MEMBERSHIPS_COLLECTION = (
    "business_memberships"
)

REPORTS_COLLECTION = "vibe_reports"

REPORT_FLAGS_COLLECTION = "report_flags"

EVENTS_COLLECTION = "events"

EVENT_REACTIONS_COLLECTION = (
    "event_reactions"
)


RECENT_AUTH_MAX_AGE_SECONDS = 5 * 60

BATCH_SIZE = 400


def require_recent_auth(
    current_user: dict,
    now_unix: int | None = None,
    max_age_seconds: int = (
        RECENT_AUTH_MAX_AGE_SECONDS
    ),
) -> str:
    uid = str(
        current_user.get(
            "uid",
            "",
        )
        or ""
    ).strip()

    if not uid:
        raise HTTPException(
            status_code=401,
            detail="Invalid user",
        )

    try:
        auth_time = int(
            current_user.get(
                "auth_time",
                0,
            )
            or 0
        )
    except (
        TypeError,
        ValueError,
    ):
        auth_time = 0

    if not auth_time:
        raise HTTPException(
            status_code=401,
            detail=(
                "Please sign in again before "
                "deleting your account."
            ),
        )

    current_time = (
        now_unix
        if now_unix is not None
        else int(
            datetime.now(
                timezone.utc
            ).timestamp()
        )
    )

    age_seconds = (
        current_time -
        auth_time
    )

    if (
        age_seconds < -60
        or age_seconds >
        max_age_seconds
    ):
        raise HTTPException(
            status_code=401,
            detail=(
                "Please sign in again before "
                "deleting your account."
            ),
        )

    return uid


def _safe_int(
    value,
) -> int:
    try:
        return max(
            0,
            int(
                value
                or 0
            ),
        )
    except (
        TypeError,
        ValueError,
    ):
        return 0


def _delete_documents(
    docs,
) -> int:
    deleted = 0

    batch = db.batch()

    pending = 0

    for doc in docs:
        batch.delete(
            doc.reference
        )

        pending += 1
        deleted += 1

        if pending >= BATCH_SIZE:
            batch.commit()

            batch = db.batch()

            pending = 0

    if pending > 0:
        batch.commit()

    return deleted


def _release_usernames(
    uid: str,
) -> int:
    docs = (
        db.collection(
            USERNAMES_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "uid",
                "==",
                uid,
            )
        )
        .stream()
    )

    return _delete_documents(
        docs
    )


def _delete_memberships(
    uid: str,
) -> int:
    docs = (
        db.collection(
            BUSINESS_MEMBERSHIPS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "user_id",
                "==",
                uid,
            )
        )
        .stream()
    )

    return _delete_documents(
        docs
    )


def _anonymize_reports(
    uid: str,
    now: datetime,
) -> int:
    docs = list(
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
        .stream()
    )

    batch = db.batch()

    pending = 0
    updated = 0

    for doc in docs:
        batch.update(
            doc.reference,
            {
                "uid":
                    "",

                "author_deleted":
                    True,

                "author_deleted_at":
                    now.isoformat(),

                "author_deleted_at_unix":
                    int(
                        now.timestamp()
                    ),

                # Defensive cleanup in case
                # older report formats ever
                # stored profile information.
                "email":
                    firestore.DELETE_FIELD,

                "username":
                    firestore.DELETE_FIELD,

                "display_name":
                    firestore.DELETE_FIELD,

                "full_name":
                    firestore.DELETE_FIELD,
            },
        )

        pending += 1
        updated += 1

        if pending >= BATCH_SIZE:
            batch.commit()

            batch = db.batch()

            pending = 0

    if pending > 0:
        batch.commit()

    return updated


def _anonymize_report_flags(
    uid: str,
    now: datetime,
) -> int:
    """
    Preserve moderation evidence without
    preserving the deleted user's identity.

    Existing flag document IDs contain the
    user UID, so each matching flag is copied
    into a fresh anonymous document and the
    identifying original is deleted.
    """

    docs = list(
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
        .stream()
    )

    changed = 0

    batch = db.batch()

    pending_operations = 0

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        data.pop(
            "flagged_by_uid",
            None,
        )

        data[
            "flagged_by_deleted_user"
        ] = True

        data[
            "anonymized_at"
        ] = now.isoformat()

        data[
            "anonymized_at_unix"
        ] = int(
            now.timestamp()
        )

        anonymous_ref = (
            db.collection(
                REPORT_FLAGS_COLLECTION
            )
            .document()
        )

        batch.set(
            anonymous_ref,
            data,
        )

        batch.delete(
            doc.reference
        )

        changed += 1
        pending_operations += 2

        if (
            pending_operations >=
            BATCH_SIZE
        ):
            batch.commit()

            batch = db.batch()

            pending_operations = 0

    if pending_operations > 0:
        batch.commit()

    return changed


def _event_owner_cleanup_update(
    status: str,
    now: datetime,
) -> dict:
    update = {
        "organizer_uid":
            "",

        "organizer_deleted":
            True,

        "organizer_deleted_at":
            now.isoformat(),

        "organizer_deleted_at_unix":
            int(
                now.timestamp()
            ),

        # Defensive cleanup for future /
        # historical event formats.
        "organizer_username":
            firestore.DELETE_FIELD,

        "organizer_full_name":
            firestore.DELETE_FIELD,

        "organizer_email":
            firestore.DELETE_FIELD,
    }

    # A submission that has not yet been
    # approved should no longer sit in the
    # admin approval queue without an owner.
    if (
        status ==
        EventStatus.PENDING.value
    ):
        update.update(
            {
                "status":
                    EventStatus
                    .CANCELLED
                    .value,

                "cancelled_at":
                    now.isoformat(),

                "cancelled_at_unix":
                    int(
                        now.timestamp()
                    ),

                "cancel_reason":
                    (
                        "Organizer account "
                        "deleted"
                    ),
            }
        )

    # Published events remain published.
    #
    # We keep the public event history but
    # remove the deleted person's identity.
    return update


def _anonymize_events(
    uid: str,
    now: datetime,
) -> int:
    docs = list(
        db.collection(
            EVENTS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "organizer_uid",
                "==",
                uid,
            )
        )
        .stream()
    )

    batch = db.batch()

    pending = 0
    updated = 0

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        status = str(
            data.get(
                "status",
                "",
            )
            or ""
        ).strip()

        update = (
            _event_owner_cleanup_update(
                status=
                    status,
                now=
                    now,
            )
        )

        batch.update(
            doc.reference,
            update,
        )

        updated += 1
        pending += 1

        if pending >= BATCH_SIZE:
            batch.commit()

            batch = db.batch()

            pending = 0

    if pending > 0:
        batch.commit()

    return updated


def _delete_event_reactions(
    uid: str,
) -> int:
    docs = list(
        db.collection(
            EVENT_REACTIONS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "user_id",
                "==",
                uid,
            )
        )
        .stream()
    )

    grouped = defaultdict(
        list
    )

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        event_id = str(
            data.get(
                "event_id",
                "",
            )
            or ""
        ).strip()

        grouped[
            event_id
        ].append(
            (
                doc,
                str(
                    data.get(
                        "type",
                        "",
                    )
                    or ""
                ).strip(),
            )
        )

    for (
        event_id,
        reactions,
    ) in grouped.items():
        if not event_id:
            _delete_documents(
                [
                    item[0]
                    for item
                    in reactions
                ]
            )

            continue

        event_ref = (
            db.collection(
                EVENTS_COLLECTION
            )
            .document(
                event_id
            )
        )

        transaction = (
            db.transaction()
        )

        @firestore.transactional
        def perform_cleanup(
            transaction,
        ):
            event_snapshot = (
                event_ref.get(
                    transaction=
                        transaction
                )
            )

            hype_removed = sum(
                1
                for _, reaction_type
                in reactions
                if reaction_type
                == "hype"
            )

            going_removed = sum(
                1
                for _, reaction_type
                in reactions
                if reaction_type
                == "going"
            )

            for (
                reaction_doc,
                _,
            ) in reactions:
                transaction.delete(
                    reaction_doc.reference
                )

            if not event_snapshot.exists:
                return

            event_data = (
                event_snapshot.to_dict()
                or {}
            )

            update = {}

            if hype_removed:
                update[
                    "hype_count"
                ] = max(
                    0,
                    _safe_int(
                        event_data.get(
                            "hype_count",
                            0,
                        )
                    )
                    - hype_removed,
                )

            if going_removed:
                update[
                    "going_count"
                ] = max(
                    0,
                    _safe_int(
                        event_data.get(
                            "going_count",
                            0,
                        )
                    )
                    - going_removed,
                )

            if update:
                transaction.update(
                    event_ref,
                    update,
                )

        perform_cleanup(
            transaction
        )

    return len(
        docs
    )


def _delete_user_profile(
    uid: str,
) -> bool:
    ref = (
        db.collection(
            USERS_COLLECTION
        )
        .document(
            uid
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        return False

    ref.delete()

    return True


def delete_yiyo_account_data(
    uid: str,
) -> dict:
    """
    Idempotent YIYO-side account cleanup.

    This intentionally does NOT delete the
    Firebase Auth user. The API endpoint does
    that only after application data cleanup
    succeeds.
    """

    clean_uid = str(
        uid
        or ""
    ).strip()

    if not clean_uid:
        raise HTTPException(
            status_code=400,
            detail="Invalid user",
        )

    now = datetime.now(
        timezone.utc
    )

    deleted_reactions = (
        _delete_event_reactions(
            clean_uid
        )
    )

    anonymized_flags = (
        _anonymize_report_flags(
            clean_uid,
            now,
        )
    )

    anonymized_reports = (
        _anonymize_reports(
            clean_uid,
            now,
        )
    )

    anonymized_events = (
        _anonymize_events(
            clean_uid,
            now,
        )
    )

    deleted_memberships = (
        _delete_memberships(
            clean_uid
        )
    )

    released_usernames = (
        _release_usernames(
            clean_uid
        )
    )

    deleted_profile = (
        _delete_user_profile(
            clean_uid
        )
    )

    return {
        "deleted_reactions":
            deleted_reactions,

        "anonymized_flags":
            anonymized_flags,

        "anonymized_reports":
            anonymized_reports,

        "anonymized_events":
            anonymized_events,

        "deleted_memberships":
            deleted_memberships,

        "released_usernames":
            released_usernames,

        "deleted_profile":
            deleted_profile,
    }