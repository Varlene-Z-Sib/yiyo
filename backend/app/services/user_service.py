import re

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

from app.models.user_model import (
    UserContributionResponse,
    UserProfileResponse,
)

from app.services.yiyo_logic import (
    contributor_level_from_count,
)


USERS_COLLECTION = "users"

USERNAMES_COLLECTION = "usernames"

REPORTS_COLLECTION = "vibe_reports"


_USERNAME_PATTERN = re.compile(
    r"^[a-z0-9][a-z0-9_]{2,23}$"
)


def normalize_username(
    value: str,
) -> str:
    return (
        str(value or "")
        .strip()
        .lstrip("@")
        .lower()
    )


def validate_username(
    value: str,
) -> str:
    normalized = (
        normalize_username(
            value
        )
    )

    if not _USERNAME_PATTERN.fullmatch(
        normalized
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Username must be 3–24 "
                "characters and use only "
                "letters, numbers, or "
                "underscores."
            ),
        )

    return normalized


def get_user_profile(
    uid: str,
    token_email: str = "",
    token_display_name: str = "",
    token_provider: str = "",
) -> UserProfileResponse:
    user_ref = (
        db.collection(
            USERS_COLLECTION
        )
        .document(
            uid
        )
    )

    snapshot = user_ref.get()

    if snapshot.exists:
        data = (
            snapshot.to_dict()
            or {}
        )
    else:
        data = {}

    report_count = int(
        data.get(
            "report_count",
            0,
        )
        or 0
    )

    contributor_level = str(
        data.get(
            "contributor_level",
            "",
        )
        or ""
    ).strip()

    if not contributor_level:
        contributor_level = (
            contributor_level_from_count(
                report_count
            )
        )

    email = str(
        data.get(
            "email",
            token_email,
        )
        or token_email
        or ""
    ).strip()

    username = str(
        data.get(
            "username",
            "",
        )
        or ""
    ).strip()

    legacy_display_name = str(
        data.get(
            "display_name",
            "",
        )
        or ""
    ).strip()

    provider = str(
        token_provider
        or ""
    ).strip()

    # Older email/password YIYO accounts
    # stored the username in display_name.
    #
    # Do not treat a Google/Apple person's
    # real display name as a YIYO username.
    if (
        not username
        and legacy_display_name
        and provider
        not in {
            "google.com",
            "apple.com",
        }
    ):
        username = (
            legacy_display_name
        )

    full_name = str(
        data.get(
            "full_name",
            "",
        )
        or ""
    ).strip()

    # Social providers can provide a useful
    # initial full-name value, but this does
    # NOT count as identity verification.
    if (
        not full_name
        and provider
        in {
            "google.com",
            "apple.com",
        }
    ):
        full_name = str(
            token_display_name
            or ""
        ).strip()

    created_at_value = data.get(
        "created_at"
    )

    created_at = (
        str(created_at_value)
        if created_at_value
        is not None
        else None
    )

    return UserProfileResponse(
        uid=
            uid,

        email=
            email,

        username=
            username,

        full_name=
            full_name,

        display_name=
            legacy_display_name,

        profile_complete=
        bool(
            username.strip()
            and str(
                data.get(
                    "username_normalized",
                    "",
                )
                or ""
            ).strip()
        ),

        report_count=
            report_count,

        contributor_level=
            contributor_level,

        created_at=
            created_at,
    )


def update_user_identity(
    uid: str,
    username: str,
    full_name: str = "",
    token_email: str = "",
) -> UserProfileResponse:
    normalized_username = (
        validate_username(
            username
        )
    )

    clean_full_name = str(
        full_name
        or ""
    ).strip()

    if len(clean_full_name) > 80:
        raise HTTPException(
            status_code=400,
            detail=(
                "Full name is too long."
            ),
        )

    user_ref = (
        db.collection(
            USERS_COLLECTION
        )
        .document(
            uid
        )
    )

    username_ref = (
        db.collection(
            USERNAMES_COLLECTION
        )
        .document(
            normalized_username
        )
    )

    transaction = (
        db.transaction()
    )

    @firestore.transactional
    def perform_update(
        transaction,
    ):
        user_snapshot = (
            user_ref.get(
                transaction=
                    transaction
            )
        )

        username_snapshot = (
            username_ref.get(
                transaction=
                    transaction
            )
        )

        if (
            username_snapshot.exists
        ):
            username_data = (
                username_snapshot
                .to_dict()
                or {}
            )

            existing_uid = str(
                username_data.get(
                    "uid",
                    "",
                )
                or ""
            )

            if (
                existing_uid
                and existing_uid != uid
            ):
                raise HTTPException(
                    status_code=409,
                    detail=(
                        "That username "
                        "is already taken."
                    ),
                )

        current_data = (
            user_snapshot.to_dict()
            if user_snapshot.exists
            else {}
        ) or {}

        old_normalized = str(
            current_data.get(
                "username_normalized",
                "",
            )
            or ""
        ).strip()

        old_username_ref = None
        old_username_snapshot = None

        if (
            old_normalized
            and old_normalized
            != normalized_username
        ):
            old_username_ref = (
                db.collection(
                    USERNAMES_COLLECTION
                )
                .document(
                    old_normalized
                )
            )

            old_username_snapshot = (
                old_username_ref.get(
                    transaction=
                        transaction
                )
            )

        now = datetime.now(
            timezone.utc
        )

        transaction.set(
            username_ref,
            {
                "uid":
                    uid,

                "username":
                    normalized_username,

                "updated_at":
                    now.isoformat(),

                "updated_at_unix":
                    int(
                        now.timestamp()
                    ),
            },
            merge=True,
        )

        transaction.set(
            user_ref,
            {
                "uid":
                    uid,

                "email":
                    str(
                        current_data.get(
                            "email",
                            token_email,
                        )
                        or token_email
                        or ""
                    ),

                "username":
                    normalized_username,

                "username_normalized":
                    normalized_username,

                "full_name":
                    clean_full_name,

                # Keep legacy field temporarily
                # so older code remains safe.
                "display_name":
                    normalized_username,

                "updated_at":
                    now.isoformat(),

                "updated_at_unix":
                    int(
                        now.timestamp()
                    ),
            },
            merge=True,
        )

        if (
            old_username_ref
            is not None
            and old_username_snapshot
            is not None
            and old_username_snapshot.exists
        ):
            old_data = (
                old_username_snapshot
                .to_dict()
                or {}
            )

            if (
                str(
                    old_data.get(
                        "uid",
                        "",
                    )
                    or ""
                )
                == uid
            ):
                transaction.delete(
                    old_username_ref
                )

    perform_update(
        transaction
    )

    return get_user_profile(
        uid=
            uid,

        token_email=
            token_email,
    )


def get_user_contributions(
    uid: str,
    limit: int = 30,
) -> list[UserContributionResponse]:
    if limit < 1 or limit > 50:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid contribution limit"
            ),
        )

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
            limit
        )
        .stream()
    )

    contributions = []

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        contribution = (
            UserContributionResponse(
                id=
                    doc.id,

                venue_id=
                    str(
                        data.get(
                            "venue_id",
                            "",
                        )
                        or ""
                    ),

                venue_name=
                    str(
                        data.get(
                            "venue_name",
                            "",
                        )
                        or ""
                    ),

                crowd_level=
                    str(
                        data.get(
                            "crowd_level",
                            "",
                        )
                        or ""
                    ),

                safety_level=
                    str(
                        data.get(
                            "safety_level",
                            "",
                        )
                        or ""
                    ),

                music_type=
                    str(
                        data.get(
                            "music_type",
                            "",
                        )
                        or ""
                    ),

                queue_length=
                    str(
                        data.get(
                            "queue_length",
                            "",
                        )
                        or ""
                    ),

                yiyo_status=
                    str(
                        data.get(
                            "yiyo_status",
                            "",
                        )
                        or ""
                    ),

                parking_availability=
                    str(
                        data.get(
                            "parking_availability",
                            "",
                        )
                        or ""
                    ),

                parking_safety=
                    str(
                        data.get(
                            "parking_safety",
                            "",
                        )
                        or ""
                    ),

                parking_note=
                    str(
                        data.get(
                            "parking_note",
                            "",
                        )
                        or ""
                    ),

                comment=
                    str(
                        data.get(
                            "comment",
                            "",
                        )
                        or ""
                    ),

                reported_at=
                    str(
                        data.get(
                            "reported_at",
                            "",
                        )
                        or ""
                    ),

                created_at_unix=
                    int(
                        data.get(
                            "created_at_unix",
                            0,
                        )
                        or 0
                    ),

                status=
                    str(
                        data.get(
                            "status",
                            "active",
                        )
                        or "active"
                    ),
            )
        )

        contributions.append(
            contribution
        )

    return contributions