import hashlib

from datetime import (
    datetime,
    timezone,
)

from fastapi import HTTPException
from google.cloud import firestore

from app.firebase_config import db

from app.models.event_engagement_model import (
    EventEngagementState,
    EventReactionResult,
    EventReactionType,
)

from app.models.event_model import (
    EventStatus,
)

from app.services.authorization_service import (
    authorization_from_user,
)


EVENTS_COLLECTION = "events"

EVENT_REACTIONS_COLLECTION = (
    "event_reactions"
)


def _reaction_document_id(
    event_id: str,
    uid: str,
    reaction: EventReactionType,
) -> str:
    """
    Deterministic document ID guarantees that one user can
    have only one reaction of each type on an event.
    """

    raw = (
        f"{event_id}|"
        f"{uid}|"
        f"{reaction.value}"
    )

    return hashlib.sha256(
        raw.encode("utf-8")
    ).hexdigest()


def _counter_field(
    reaction: EventReactionType,
) -> str:
    if (
        reaction
        == EventReactionType.HYPE
    ):
        return "hype_count"

    return "going_count"


def _safe_count(
    value,
) -> int:
    try:
        count = int(
            value or 0
        )
    except (
        TypeError,
        ValueError,
    ):
        return 0

    return max(
        0,
        count,
    )


def calculate_reaction_toggle(
    current_count: int,
    reaction_exists: bool,
) -> tuple[bool, int]:
    """
    Pure helper used by the transaction.

    Returns:

        (reaction_active_after_toggle, new_count)
    """

    safe_count = max(
        0,
        int(current_count),
    )

    if reaction_exists:
        return (
            False,
            max(
                0,
                safe_count - 1,
            ),
        )

    return (
        True,
        safe_count + 1,
    )


def toggle_event_reaction(
    event_id: str,
    current_user: dict,
    reaction: EventReactionType,
) -> EventReactionResult:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    event_ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    reaction_id = (
        _reaction_document_id(
            event_id=
                event_id,

            uid=
                auth.uid,

            reaction=
                reaction,
        )
    )

    reaction_ref = (
        db.collection(
            EVENT_REACTIONS_COLLECTION
        )
        .document(
            reaction_id
        )
    )

    counter_field = (
        _counter_field(
            reaction
        )
    )

    transaction = (
        db.transaction()
    )

    @firestore.transactional
    def perform_toggle(
        transaction,
    ):
        event_snapshot = (
            event_ref.get(
                transaction=
                    transaction
            )
        )

        if not event_snapshot.exists:
            raise HTTPException(
                status_code=404,
                detail="Event not found",
            )

        event_data = (
            event_snapshot.to_dict()
            or {}
        )

        # Only publicly published events can receive
        # audience engagement.
        if (
            event_data.get(
                "status"
            )
            != EventStatus
            .PUBLISHED
            .value
        ):
            raise HTTPException(
                status_code=404,
                detail="Event not found",
            )

        reaction_snapshot = (
            reaction_ref.get(
                transaction=
                    transaction
            )
        )

        current_count = (
            _safe_count(
                event_data.get(
                    counter_field
                )
            )
        )

        active, new_count = (
            calculate_reaction_toggle(
                current_count=
                    current_count,

                reaction_exists=
                    reaction_snapshot
                    .exists,
            )
        )

        now = datetime.now(
            timezone.utc
        )

        if active:
            transaction.set(
                reaction_ref,
                {
                    "event_id":
                        event_id,

                    "user_id":
                        auth.uid,

                    "type":
                        reaction.value,

                    "created_at":
                        now.isoformat(),

                    "created_at_unix":
                        int(
                            now.timestamp()
                        ),
                },
            )

        else:
            transaction.delete(
                reaction_ref
            )

        transaction.update(
            event_ref,
            {
                counter_field:
                    new_count
            },
        )

        return (
            active,
            new_count,
        )

    active, new_count = (
        perform_toggle(
            transaction
        )
    )

    return EventReactionResult(
        event_id=event_id,
        reaction=reaction,
        active=active,
        count=new_count,
    )


def get_event_engagement_state(
    event_id: str,
    current_user: dict,
) -> EventEngagementState:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    event_ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    event_snapshot = (
        event_ref.get()
    )

    if not event_snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    event_data = (
        event_snapshot.to_dict()
        or {}
    )

    if (
        event_data.get(
            "status"
        )
        != EventStatus
        .PUBLISHED
        .value
    ):
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    hype_ref = (
        db.collection(
            EVENT_REACTIONS_COLLECTION
        )
        .document(
            _reaction_document_id(
                event_id=
                    event_id,

                uid=
                    auth.uid,

                reaction=
                    EventReactionType
                    .HYPE,
            )
        )
    )

    going_ref = (
        db.collection(
            EVENT_REACTIONS_COLLECTION
        )
        .document(
            _reaction_document_id(
                event_id=
                    event_id,

                uid=
                    auth.uid,

                reaction=
                    EventReactionType
                    .GOING,
            )
        )
    )

    reaction_snapshots = list(
        db.get_all(
            [
                hype_ref,
                going_ref,
            ]
        )
    )

    existing_ids = {
        snapshot.id
        for snapshot
        in reaction_snapshots
        if snapshot.exists
    }

    return EventEngagementState(
        event_id=
            event_id,

        hype_count=
            _safe_count(
                event_data.get(
                    "hype_count"
                )
            ),

        going_count=
            _safe_count(
                event_data.get(
                    "going_count"
                )
            ),

        hyped_by_me=(
            hype_ref.id
            in existing_ids
        ),

        going_by_me=(
            going_ref.id
            in existing_ids
        ),
    )