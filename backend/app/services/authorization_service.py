import hashlib

from datetime import (
    datetime,
    timezone,
)

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import (
    FieldFilter,
)

from app.firebase_config import db

from app.models.authorization_model import (
    AppRole,
    AuthorizationContext,
    BusinessMembership,
    EffectivePermissions,
    MembershipRole,
    MembershipStatus,
)


BUSINESS_MEMBERSHIPS_COLLECTION = (
    "business_memberships"
)


def authorization_from_user(
    current_user: dict,
) -> AuthorizationContext:
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

    raw_role = str(
        current_user.get(
            "app_role",
            "user",
        )
        or "user"
    ).strip().lower()

    try:
        app_role = AppRole(
            raw_role
        )
    except ValueError:
        app_role = (
            AppRole.USER
        )

    return AuthorizationContext(
        uid=uid,
        app_role=app_role,
    )


def require_moderator(
    current_user: dict,
) -> AuthorizationContext:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    if not auth.is_moderator:
        raise HTTPException(
            status_code=403,
            detail=(
                "Moderator access "
                "required"
            ),
        )

    return auth


def require_super_admin(
    current_user: dict,
) -> AuthorizationContext:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    if not auth.is_super_admin:
        raise HTTPException(
            status_code=403,
            detail=(
                "Super admin access "
                "required"
            ),
        )

    return auth


def _membership_document_id(
    user_id: str,
    role: MembershipRole,
    venue_id: str | None,
) -> str:
    """
    Deterministic ID prevents duplicate grants
    for the same user/role/venue combination.
    """

    raw_key = (
        f"{user_id}|"
        f"{role.value}|"
        f"{venue_id or ''}"
    )

    return hashlib.sha256(
        raw_key.encode(
            "utf-8"
        )
    ).hexdigest()


def get_user_memberships(
    uid: str,
) -> list[BusinessMembership]:
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

    memberships = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        try:
            membership = (
                BusinessMembership(
                    id=doc.id,
                    **data,
                )
            )

            memberships.append(
                membership
            )

        except Exception as e:
            print(
                "[WARN] Invalid business "
                "membership "
                f"{doc.id}: {e}"
            )

    return memberships


def _active_memberships(
    memberships: list[
        BusinessMembership
    ],
) -> list[BusinessMembership]:
    return [
        membership
        for membership
        in memberships
        if (
            membership.status
            == MembershipStatus.ACTIVE
        )
    ]


def get_effective_permissions(
    current_user: dict,
) -> EffectivePermissions:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    memberships = (
        _active_memberships(
            get_user_memberships(
                auth.uid
            )
        )
    )

    is_promoter = any(
        membership.role
        == MembershipRole.PROMOTER
        for membership
        in memberships
    )

    managed_venue_ids = sorted(
        {
            membership.venue_id
            for membership
            in memberships
            if (
                membership.role
                == MembershipRole.VENUE_MANAGER
                and membership.venue_id
            )
        }
    )

    can_create_events = (
        auth.is_super_admin
        or is_promoter
        or bool(
            managed_venue_ids
        )
    )

    can_manage_venues = (
        auth.is_super_admin
        or bool(
            managed_venue_ids
        )
    )

    return EffectivePermissions(
        uid=auth.uid,

        app_role=
            auth.app_role,

        is_promoter=
            is_promoter,

        managed_venue_ids=
            managed_venue_ids,

        moderate_content=
            auth.is_moderator,

        super_admin=
            auth.is_super_admin,

        create_events=
            can_create_events,

        manage_venues=
            can_manage_venues,
    )


def can_create_event(
    current_user: dict,
    venue_id: str,
) -> bool:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    if auth.is_super_admin:
        return True

    memberships = (
        _active_memberships(
            get_user_memberships(
                auth.uid
            )
        )
    )

    for membership in memberships:
        if (
            membership.role
            == MembershipRole.PROMOTER
        ):
            return True

        if (
            membership.role
            == MembershipRole.VENUE_MANAGER
            and membership.venue_id
            == venue_id
        ):
            return True

    return False


def can_manage_venue(
    current_user: dict,
    venue_id: str,
) -> bool:
    auth = (
        authorization_from_user(
            current_user
        )
    )

    if auth.is_super_admin:
        return True

    memberships = (
        _active_memberships(
            get_user_memberships(
                auth.uid
            )
        )
    )

    return any(
        membership.role
        == MembershipRole.VENUE_MANAGER
        and membership.venue_id
        == venue_id
        for membership
        in memberships
    )


def grant_business_membership(
    user_id: str,
    role: MembershipRole,
    venue_id: str | None = None,
) -> BusinessMembership:
    """
    Super-admin-controlled membership grant.

    Re-granting the same membership reactivates it
    instead of creating a duplicate document.
    """

    if (
        role
        == MembershipRole.VENUE_MANAGER
        and not (
            venue_id
            or ""
        ).strip()
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "venue_id is required "
                "for venue_manager"
            ),
        )

    if (
        role
        == MembershipRole.PROMOTER
        and venue_id is not None
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Promoter membership "
                "must not include venue_id"
            ),
        )

    normalized_venue_id = (
        venue_id.strip()
        if venue_id
        else None
    )

    membership_id = (
        _membership_document_id(
            user_id=user_id,
            role=role,
            venue_id=
                normalized_venue_id,
        )
    )

    ref = (
        db.collection(
            BUSINESS_MEMBERSHIPS_COLLECTION
        )
        .document(
            membership_id
        )
    )

    existing = ref.get()

    now = datetime.now(
        timezone.utc
    )

    payload = {
        "user_id":
            user_id,

        "role":
            role.value,

        "venue_id":
            normalized_venue_id,

        "status":
            MembershipStatus.ACTIVE.value,

        "updated_at":
            now.isoformat(),

        "updated_at_unix":
            int(
                now.timestamp()
            ),
    }

    if not existing.exists:
        payload.update(
            {
                "created_at":
                    now.isoformat(),

                "created_at_unix":
                    int(
                        now.timestamp()
                    ),
            }
        )

    ref.set(
        payload,
        merge=True,
    )

    stored = (
        ref.get().to_dict()
        or payload
    )

    return BusinessMembership(
        id=membership_id,
        **stored,
    )


def suspend_business_membership(
    membership_id: str,
) -> BusinessMembership:
    ref = (
        db.collection(
            BUSINESS_MEMBERSHIPS_COLLECTION
        )
        .document(
            membership_id
        )
    )

    snapshot = ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail=(
                "Membership not found"
            ),
        )

    now = datetime.now(
        timezone.utc
    )

    ref.set(
        {
            "status":
                MembershipStatus
                .SUSPENDED
                .value,

            "updated_at":
                now.isoformat(),

            "updated_at_unix":
                int(
                    now.timestamp()
                ),
        },
        merge=True,
    )

    updated = (
        ref.get().to_dict()
        or {}
    )

    return BusinessMembership(
        id=membership_id,
        **updated,
    )