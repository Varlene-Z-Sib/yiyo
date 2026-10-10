from datetime import (
    datetime,
    timedelta,
    timezone,
)

from fastapi import HTTPException
from google.cloud import firestore

from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db

from app.models.authorization_model import (
    EffectivePermissions,
)
from app.services.authorization_service import (
    authorization_from_user,
    can_manage_venue,
    get_effective_permissions,
)

from app.models.event_model import (
    EventApprovalResponse,
    EventCreate,
    EventResponse,
    EventStatus,
    EventUpdate,
)

USERS_COLLECTION = "users"

EVENTS_COLLECTION = "events"

def _load_organizer_profiles(
    organizer_uids: set[str],
) -> dict[str, dict]:
    clean_uids = {
        str(uid or "").strip()
        for uid in organizer_uids
        if str(uid or "").strip()
    }

    if not clean_uids:
        return {}

    refs = [
        db.collection(
            USERS_COLLECTION
        )
        .document(
            uid
        )
        for uid in clean_uids
    ]

    profiles = {}

    for snapshot in db.get_all(
        refs
    ):
        if not snapshot.exists:
            continue

        profiles[
            snapshot.id
        ] = (
            snapshot.to_dict()
            or {}
        )

    return profiles

def determine_initial_event_status(
    permissions: EffectivePermissions,
    venue_id: str,
) -> EventStatus:
    """
    Publication rules:

    super_admin:
        may publish anywhere.

    venue_manager:
        may publish immediately for a venue
        they manage.

    promoter:
        may submit events, but they begin
        pending until approved.

    regular users:
        may not create events.
    """

    if permissions.super_admin:
        return EventStatus.PUBLISHED

    if (
        venue_id
        in permissions.managed_venue_ids
    ):
        return EventStatus.PUBLISHED

    if permissions.is_promoter:
        return EventStatus.PENDING

    raise HTTPException(
        status_code=403,
        detail=(
            "You do not have permission "
            "to create events"
        ),
    )


def _float_or_none(
    value,
) -> float | None:
    try:
        if value is None:
            return None

        return float(value)

    except (
        TypeError,
        ValueError,
    ):
        return None

def validate_event_is_future(
    starts_at: datetime,
    now: datetime | None = None,
) -> None:
    current_time = (
        now
        or datetime.now(
            timezone.utc
        )
    )

    normalized_start = (
        starts_at.astimezone(
            timezone.utc
        )
    )

    if (
        normalized_start
        <= current_time
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Event start time "
                "must be in the future"
            ),
        )

def event_visibility_end(
    starts_at: datetime,
    ends_at: datetime | None,
) -> datetime:
    """
    Decide how long an event remains discoverable.

    If an organiser supplied an end time, use it.

    Otherwise keep the event discoverable for 8 hours
    after its start time. This prevents nightlife events
    disappearing from YIYO as soon as they begin.
    """

    if ends_at is not None:
        return ends_at.astimezone(
            timezone.utc
        )

    return (
        starts_at.astimezone(
            timezone.utc
        )
        + timedelta(
            hours=8
        )
    )

def is_event_status_cancellable(
    status: str,
) -> bool:
    return status in {
        EventStatus.PENDING.value,
        EventStatus.PUBLISHED.value,
    }

def determine_event_edit_mode(
    permissions: EffectivePermissions,
    organizer_uid: str,
    venue_id: str,
    status: EventStatus,
) -> str:
    """
    Returns:

    direct
        Change can be applied immediately.

    reapproval
        Change is allowed but the event
        must return to pending review.

    forbidden
        User may not edit the event.
    """

    if status in {
        EventStatus.CANCELLED,
        EventStatus.REJECTED,
    }:
        return "forbidden"

    if permissions.super_admin:
        return "direct"

    if (
        venue_id
        in permissions.managed_venue_ids
    ):
        return "direct"

    if (
        permissions.is_promoter
        and permissions.uid
        == organizer_uid
    ):
        if (
            status ==
            EventStatus.PENDING
        ):
            return "direct"

        if (
            status ==
            EventStatus.PUBLISHED
        ):
            return "reapproval"

    return "forbidden"


def can_cancel_event_with_context(
    *,
    actor_uid: str,
    organizer_uid: str,
    is_super_admin: bool,
    manages_venue: bool,
) -> bool:
    if is_super_admin:
        return True

    if (
        actor_uid
        and actor_uid == organizer_uid
    ):
        return True

    if manages_venue:
        return True

    return False

def can_hard_delete_event_with_context(
    *,
    permissions,
    organizer_uid: str,
    venue_id: str,
    status: EventStatus,
) -> bool:
    # Super admin can permanently remove
    # any event, including published events.
    if permissions.super_admin:
        return True

    # Published real events should normally
    # be cancelled rather than erased.
    if (
        status ==
        EventStatus.PUBLISHED
    ):
        return False

    # Venue managers may permanently remove
    # non-published events for venues they
    # are responsible for.
    if (
        venue_id
        in permissions.managed_venue_ids
    ):
        return True

    # Promoters may permanently remove only
    # their own non-published submissions.
    return (
        permissions.is_promoter
        and permissions.uid
        == organizer_uid
    )

def _parse_event_datetime(
    value,
) -> datetime | None:
    if value in {
        None,
        "",
    }:
        return None

    if isinstance(
        value,
        datetime,
    ):
        parsed = value

    else:
        try:
            parsed = (
                datetime.fromisoformat(
                    str(value)
                )
            )
        except ValueError:
            return None

    if parsed.tzinfo is None:
        return parsed.replace(
            tzinfo=timezone.utc
        )

    return parsed.astimezone(
        timezone.utc
    )

def create_event(
    request: EventCreate,
    current_user: dict,
    canonical_venue: dict,
) -> EventResponse:
    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    status = (
        determine_initial_event_status(
            permissions,
            request.venue_id,
        )
    )

    venue_name = str(
        canonical_venue.get(
            "name",
            "",
        )
        or ""
    ).strip()

    if not venue_name:
        raise HTTPException(
            status_code=400,
            detail=(
                "Venue has no canonical "
                "name"
            ),
        )

    now = datetime.now(
        timezone.utc
    )

    starts_at = (
        request.starts_at
        .astimezone(
            timezone.utc
        )
    )

    validate_event_is_future(
    starts_at
)

    ends_at = (
        request.ends_at.astimezone(
            timezone.utc
        )
        if request.ends_at
        else None
    )

    visibility_ends_at = (
        event_visibility_end(
            starts_at=starts_at,
            ends_at=ends_at,
        )
    ) 

    doc_ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document()
    )

    payload = {
        "title":
            request.title,

        "description":
            request.description,

        "venue_id":
            request.venue_id,

        "venue_name":
            venue_name,

        "venue_address":
            str(
                canonical_venue.get(
                    "address",
                    "",
                )
                or ""
            ),

        "venue_lat":
            _float_or_none(
                canonical_venue.get(
                    "lat"
                )
            ),

        "venue_lng":
            _float_or_none(
                canonical_venue.get(
                    "lng"
                )
            ),

        "organizer_uid":
            permissions.uid,

        "status":
            status.value,

        "starts_at":
            starts_at.isoformat(),

        "starts_at_unix":
            int(
                starts_at.timestamp()
            ),

        "ends_at":
            (
                ends_at.isoformat()
                if ends_at
                else None
            ),

        "ends_at_unix":
            (
                int(
                    ends_at.timestamp()
                )
                if ends_at
                else None
            ),

        "poster_url":
            request.poster_url,

        "ticket_url":
            request.ticket_url,

        "tags":
            request.tags,

        "hype_count":
            0,

        "going_count":
            0,

        "created_at":
            now.isoformat(),

        "created_at_unix":
            int(
                now.timestamp()
            ),
        "visibility_ends_at":
            visibility_ends_at.isoformat(),

        "visibility_ends_at_unix":
            int(
                visibility_ends_at.timestamp()
            ),
    }

    if (
        status
        == EventStatus.PUBLISHED
    ):
        payload[
            "published_at"
        ] = now.isoformat()

        payload[
            "published_at_unix"
        ] = int(
            now.timestamp()
        )

    doc_ref.set(
        payload
    )

    return EventResponse(
        id=doc_ref.id,
        **payload,
    )


def get_public_event(
    event_id: str,
) -> EventResponse:
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

    data = (
        snapshot.to_dict()
        or {}
    )

    if (
        data.get("status")
        != EventStatus
        .PUBLISHED
        .value
    ):
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    return EventResponse(
        id=snapshot.id,
        **data,
    )


def get_upcoming_events(
    limit: int = 30,
) -> list[EventResponse]:
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail="Invalid event limit",
        )

    now_unix = int(
        datetime.now(
            timezone.utc
        ).timestamp()
    )

    docs = (
        db.collection(
            EVENTS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "status",
                "==",
                EventStatus
                .PUBLISHED
                .value,
            )
        )
        .where(
            filter=FieldFilter(
                "visibility_ends_at_unix",
                ">=",
                now_unix,
            )
        )
        .order_by(
            "visibility_ends_at_unix",
            direction="ASCENDING",
        )
        .limit(
            limit
        )
        .stream()
    )

    events = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        try:
            events.append(
                EventResponse(
                    id=doc.id,
                    **data,
                )
            )

        except Exception as e:
            print(
                "[WARN] Invalid event "
                f"{doc.id}: {e}"
            )
        events.sort(
            key=lambda event:
                event.starts_at_unix
        )

    return events


def approve_event(
    event_id: str,
    current_user: dict,
) -> EventResponse:
    ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    data = (
        snapshot.to_dict()
        or {}
    )

    venue_id = str(
        data.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    if not venue_id:
        raise HTTPException(
            status_code=400,
            detail=(
                "Event has no venue"
            ),
        )

    if not can_manage_venue(
        current_user,
        venue_id,
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "You cannot approve "
                "events for this venue"
            ),
        )

    current_status = str(
        data.get(
            "status",
            "",
        )
        or ""
    )

    if (
        current_status
        == EventStatus
        .PUBLISHED
        .value
    ):
        return EventResponse(
            id=event_id,
            **data,
        )

    if (
        current_status
        != EventStatus
        .PENDING
        .value
    ):
        raise HTTPException(
            status_code=409,
            detail=(
                "Only pending events "
                "can be approved"
            ),
        )

    now = datetime.now(
        timezone.utc
    )

    approver_permissions = (
    get_effective_permissions(
        current_user
    )
)

    update = {
        "status":
            EventStatus.PUBLISHED.value,

        "published_at":
            now.isoformat(),

        "published_at_unix":
            int(
                now.timestamp()
            ),

        "approved_by_uid":
            approver_permissions.uid,

        "updated_at":
            now.isoformat(),

        "updated_at_unix":
            int(
                now.timestamp()
            ),

        "updated_by_uid":
            approver_permissions.uid,
    }

    ref.set(
        update,
        merge=True,
    )

    data.update(
        update
    )

    return EventResponse(
        id=event_id,
        **data,
    )

def get_user_events(
    current_user: dict,
    limit: int = 50,
) -> list[EventResponse]:
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail="Invalid event limit",
        )

    auth = authorization_from_user(
        current_user
    )

    docs = (
        db.collection(
            EVENTS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "organizer_uid",
                "==",
                auth.uid,
            )
        )
        .stream()
    )

    events = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        try:
            events.append(
                EventResponse(
                    id=doc.id,
                    **data,
                )
            )

        except Exception as e:
            print(
                "[WARN] Invalid user event "
                f"{doc.id}: {e}"
            )

    events.sort(
        key=lambda event:
            event.created_at_unix,
        reverse=True,
    )

    return events[:limit]


def cancel_event(
    event_id: str,
    current_user: dict,
) -> EventResponse:
    auth = authorization_from_user(
        current_user
    )

    ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    data = (
        snapshot.to_dict()
        or {}
    )

    organizer_uid = str(
        data.get(
            "organizer_uid",
            "",
        )
        or ""
    ).strip()

    venue_id = str(
        data.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    manages_venue = False

    # Avoid an unnecessary Firestore membership query
    # when the user is already the creator or super admin.
    if (
        not auth.is_super_admin
        and auth.uid != organizer_uid
        and venue_id
    ):
        manages_venue = (
            can_manage_venue(
                current_user,
                venue_id,
            )
        )

    allowed = (
        can_cancel_event_with_context(
            actor_uid=
                auth.uid,

            organizer_uid=
                organizer_uid,

            is_super_admin=
                auth.is_super_admin,

            manages_venue=
                manages_venue,
        )
    )

    if not allowed:
        raise HTTPException(
            status_code=403,
            detail=(
                "You cannot cancel "
                "this event"
            ),
        )

    current_status = str(
        data.get(
            "status",
            "",
        )
        or ""
    )

    if (
        current_status
        == EventStatus.CANCELLED.value
    ):
        return EventResponse(
            id=event_id,
            **data,
        )

    if not is_event_status_cancellable(
        current_status
    ):
        raise HTTPException(
            status_code=409,
            detail=(
                "This event cannot "
                "be cancelled"
            ),
        )

    now = datetime.now(
        timezone.utc
    )

    update = {
        "status":
            EventStatus.CANCELLED.value,

        "cancelled_at":
            now.isoformat(),

        "cancelled_at_unix":
            int(
                now.timestamp()
            ),

        "cancelled_by_uid":
            auth.uid,

        "updated_at":
            now.isoformat(),

        "updated_at_unix":
            int(
                now.timestamp()
            ),

        "updated_by_uid":
            auth.uid,
    }

    ref.set(
        update,
        merge=True,
    )

    data.update(
        update
    )

    return EventResponse(
        id=event_id,
        **data,
    )

def can_review_event_with_context(
    *,
    is_super_admin: bool,
    managed_venue_ids: list[str],
    venue_id: str,
) -> bool:
    if is_super_admin:
        return True

    return venue_id in managed_venue_ids


def is_event_pending_approval(
    status: str,
) -> bool:
    return (
        status
        == EventStatus.PENDING.value
    )

def get_pending_event_approvals(
    current_user: dict,
    limit: int = 50,
) -> list[EventApprovalResponse]:
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail="Invalid event limit",
        )

    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    if (
        not permissions.super_admin
        and not permissions.managed_venue_ids
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "You do not have permission "
                "to review events"
            ),
        )

    # Cheap MVP query:
    #
    # Query only pending events, then filter
    # venue access in Python. Firestore creates
    # single-field indexes automatically, so
    # this avoids another composite index.
    docs = (
        db.collection(
            EVENTS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "status",
                "==",
                EventStatus.PENDING.value,
            )
        )
        .stream()
    )

    events = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        venue_id = str(
            data.get(
                "venue_id",
                "",
            )
            or ""
        ).strip()

        if not can_review_event_with_context(
            is_super_admin=
                permissions.super_admin,

            managed_venue_ids=
                permissions.managed_venue_ids,

            venue_id=
                venue_id,
        ):
            continue

        try:
            events.append(
                EventResponse(
                    id=doc.id,
                    **data,
                )
            )

        except Exception as e:
            print(
                "[WARN] Invalid pending "
                "event "
                f"{doc.id}: {e}"
            )

    events.sort(
        key=lambda event:
            event.created_at_unix,
        reverse=True,
    )

    # Apply the requested limit first.
    events = events[:limit]

    # Load each organiser profile only once.
    organizer_profiles = (
        _load_organizer_profiles(
            {
                event.organizer_uid
                for event in events
                if event.organizer_uid
            }
        )
    )

    approvals = []

    for event in events:
        profile = (
            organizer_profiles.get(
                event.organizer_uid,
                {},
            )
        )

        username = str(
            profile.get(
                "username",
                "",
            )
            or profile.get(
                "display_name",
                "",
            )
            or ""
        ).strip()

        full_name = str(
            profile.get(
                "full_name",
                "",
            )
            or ""
        ).strip()

        email = str(
            profile.get(
                "email",
                "",
            )
            or ""
        ).strip()

        approvals.append(
            EventApprovalResponse(
                **event.model_dump(),

                organizer_username=
                    username,

                organizer_full_name=
                    full_name,

                organizer_email=
                    email,
            )
        )

    return approvals


def reject_event(
    event_id: str,
    current_user: dict,
) -> EventResponse:
    ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    data = (
        snapshot.to_dict()
        or {}
    )

    venue_id = str(
        data.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    if not venue_id:
        raise HTTPException(
            status_code=400,
            detail=(
                "Event has no venue"
            ),
        )

    if not can_manage_venue(
        current_user,
        venue_id,
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "You cannot review "
                "events for this venue"
            ),
        )

    current_status = str(
        data.get(
            "status",
            "",
        )
        or ""
    )

    if (
        current_status
        == EventStatus.REJECTED.value
    ):
        return EventResponse(
            id=event_id,
            **data,
        )

    if not is_event_pending_approval(
        current_status
    ):
        raise HTTPException(
            status_code=409,
            detail=(
                "Only pending events "
                "can be rejected"
            ),
        )

    auth = authorization_from_user(
        current_user
    )

    now = datetime.now(
        timezone.utc
    )

    update = {
        "status":
            EventStatus.REJECTED.value,

        "rejected_at":
            now.isoformat(),

        "rejected_at_unix":
            int(
                now.timestamp()
            ),

        "rejected_by_uid":
            auth.uid,
    }

    ref.set(
        update,
        merge=True,
    )

    data.update(
        update
    )

    return EventResponse(
        id=event_id,
        **data,
    )

def update_event(
    event_id: str,
    request: EventUpdate,
    current_user: dict,
) -> EventResponse:
    ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    data = (
        snapshot.to_dict()
        or {}
    )

    organizer_uid = str(
        data.get(
            "organizer_uid",
            "",
        )
        or ""
    ).strip()

    venue_id = str(
        data.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    try:
        status = EventStatus(
            str(
                data.get(
                    "status",
                    "",
                )
                or ""
            )
        )

    except ValueError:
        raise HTTPException(
            status_code=409,
            detail="Invalid event status",
        )

    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    edit_mode = (
        determine_event_edit_mode(
            permissions=
                permissions,

            organizer_uid=
                organizer_uid,

            venue_id=
                venue_id,

            status=
                status,
        )
    )

    if edit_mode == "forbidden":
        raise HTTPException(
            status_code=403,
            detail=(
                "You cannot edit "
                "this event"
            ),
        )

    fields = (
        request.model_fields_set
    )

    update = {}

    if "title" in fields:
        update["title"] = (
            request.title
        )

    if "description" in fields:
        update["description"] = (
            request.description
        )

    if "poster_url" in fields:
        update["poster_url"] = (
            request.poster_url
        )

    if "ticket_url" in fields:
        update["ticket_url"] = (
            request.ticket_url
        )

    if "tags" in fields:
        update["tags"] = (
            request.tags
            or []
        )

    existing_start = (
        _parse_event_datetime(
            data.get(
                "starts_at"
            )
        )
    )

    existing_end = (
        _parse_event_datetime(
            data.get(
                "ends_at"
            )
        )
    )

    if existing_start is None:
        raise HTTPException(
            status_code=409,
            detail=(
                "Event has an invalid "
                "start time"
            ),
        )

    starts_at = (
        request.starts_at
        .astimezone(
            timezone.utc
        )
        if "starts_at" in fields
        else existing_start
    )

    ends_at = (
        (
            request.ends_at
            .astimezone(
                timezone.utc
            )
            if request.ends_at
            is not None
            else None
        )
        if "ends_at" in fields
        else existing_end
    )

    if "starts_at" in fields:
        validate_event_is_future(
            starts_at
        )

    if (
        ends_at is not None
        and ends_at <= starts_at
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Event end time must be "
                "after start time"
            ),
        )

    if (
        "starts_at" in fields
        or "ends_at" in fields
    ):
        visibility_ends_at = (
            event_visibility_end(
                starts_at=
                    starts_at,

                ends_at=
                    ends_at,
            )
        )

        update.update(
            {
                "starts_at":
                    starts_at.isoformat(),

                "starts_at_unix":
                    int(
                        starts_at.timestamp()
                    ),

                "ends_at":
                    (
                        ends_at.isoformat()
                        if ends_at
                        else None
                    ),

                "ends_at_unix":
                    (
                        int(
                            ends_at.timestamp()
                        )
                        if ends_at
                        else None
                    ),

                "visibility_ends_at":
                    visibility_ends_at
                    .isoformat(),

                "visibility_ends_at_unix":
                    int(
                        visibility_ends_at
                        .timestamp()
                    ),
            }
        )

    now = datetime.now(
        timezone.utc
    )

    update.update(
        {
            "updated_at":
                now.isoformat(),

            "updated_at_unix":
                int(
                    now.timestamp()
                ),

            "updated_by_uid":
                permissions.uid,
        }
    )

    # A promoter may fix their own
    # published event, but the edited
    # version must be reviewed again.
    if (
        edit_mode ==
        "reapproval"
    ):
        update.update(
            {
                "status":
                    EventStatus
                    .PENDING
                    .value,

                "resubmitted_at":
                    now.isoformat(),

                "resubmitted_at_unix":
                    int(
                        now.timestamp()
                    ),

                "approved_by_uid":
                    firestore
                    .DELETE_FIELD,
            }
        )

    ref.update(
        update
    )

    refreshed = ref.get()

    refreshed_data = (
        refreshed.to_dict()
        or {}
    )

    return EventResponse(
        id=
            event_id,
        **refreshed_data,
    )

def delete_event(
    event_id: str,
    current_user: dict,
) -> dict:
    ref = (
        db.collection(
            EVENTS_COLLECTION
        )
        .document(
            event_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="Event not found",
        )

    data = (
        snapshot.to_dict()
        or {}
    )

    organizer_uid = str(
        data.get(
            "organizer_uid",
            "",
        )
        or ""
    ).strip()

    venue_id = str(
        data.get(
            "venue_id",
            "",
        )
        or ""
    ).strip()

    try:
        status = EventStatus(
            str(
                data.get(
                    "status",
                    "",
                )
                or ""
            )
        )

    except ValueError:
        raise HTTPException(
            status_code=409,
            detail="Invalid event status",
        )

    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    if not (
        can_hard_delete_event_with_context(
            permissions=
                permissions,

            organizer_uid=
                organizer_uid,

            venue_id=
                venue_id,

            status=
                status,
        )
    ):
        if (
            status ==
            EventStatus.PUBLISHED
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    "Published events should "
                    "be cancelled instead "
                    "of deleted."
                ),
            )

        raise HTTPException(
            status_code=403,
            detail=(
                "You cannot delete "
                "this event"
            ),
        )

    ref.delete()

    return {
        "deleted":
            True,

        "event_id":
            event_id,
    }

def get_manageable_events(
    current_user: dict,
    limit: int = 100,
) -> list[EventResponse]:
    if limit < 1 or limit > 200:
        raise HTTPException(
            status_code=400,
            detail="Invalid event limit",
        )

    permissions = (
        get_effective_permissions(
            current_user
        )
    )

    if (
        not permissions.super_admin
        and not permissions
        .managed_venue_ids
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "You do not have permission "
                "to manage venue events"
            ),
        )

    # Cheap launch query.
    #
    # Super-admin gets all events.
    # Venue managers are filtered by
    # their managed venue IDs in Python.
    docs = (
        db.collection(
            EVENTS_COLLECTION
        )
        .stream()
    )

    events = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        venue_id = str(
            data.get(
                "venue_id",
                "",
            )
            or ""
        ).strip()

        if (
            not permissions.super_admin
            and venue_id
            not in permissions
            .managed_venue_ids
        ):
            continue

        try:
            events.append(
                EventResponse(
                    id=
                        doc.id,
                    **data,
                )
            )

        except Exception as e:
            print(
                "[WARN] Invalid managed "
                "event "
                f"{doc.id}: {e}"
            )

    events.sort(
        key=lambda event:
            event.created_at_unix,
        reverse=True,
    )

    return events[:limit]