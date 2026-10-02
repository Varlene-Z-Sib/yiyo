from datetime import (
    datetime,
    timedelta,
    timezone,
)

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db

from app.models.authorization_model import (
    EffectivePermissions,
)

from app.models.event_model import (
    EventCreate,
    EventResponse,
    EventStatus,
)

from app.services.authorization_service import (
    can_manage_venue,
    get_effective_permissions,
)


EVENTS_COLLECTION = "events"


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

    update = {
        "status":
            EventStatus
            .PUBLISHED
            .value,

        "published_at":
            now.isoformat(),

        "published_at_unix":
            int(
                now.timestamp()
            ),
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