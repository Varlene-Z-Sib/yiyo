from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.models.user_model import (
    UserContributionResponse,
    UserProfileResponse,
)
from app.services.yiyo_logic import (
    contributor_level_from_count,
)


USERS_COLLECTION = "users"
REPORTS_COLLECTION = "vibe_reports"


def get_user_profile(
    uid: str,
    token_email: str = "",
    token_display_name: str = "",
) -> UserProfileResponse:
    user_ref = (
        db.collection(USERS_COLLECTION)
        .document(uid)
    )

    snapshot = user_ref.get()

    if snapshot.exists:
        data = snapshot.to_dict() or {}
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
    )

    display_name = str(
        data.get(
            "display_name",
            token_display_name,
        )
        or token_display_name
        or ""
    )

    created_at_value = data.get(
        "created_at"
    )

    created_at = (
        str(created_at_value)
        if created_at_value is not None
        else None
    )

    return UserProfileResponse(
        uid=uid,
        email=email,
        display_name=display_name,
        report_count=report_count,
        contributor_level=contributor_level,
        created_at=created_at,
    )


def get_user_contributions(
    uid: str,
    limit: int = 30,
) -> list[UserContributionResponse]:
    if limit < 1 or limit > 50:
        raise HTTPException(
            status_code=400,
            detail="Invalid contribution limit",
        )

    docs = (
        db.collection(REPORTS_COLLECTION)
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
        .limit(limit)
        .stream()
    )

    contributions = []

    for doc in docs:
        data = doc.to_dict() or {}

        contribution = (
            UserContributionResponse(
                id=doc.id,

                venue_id=str(
                    data.get(
                        "venue_id",
                        "",
                    )
                    or ""
                ),

                venue_name=str(
                    data.get(
                        "venue_name",
                        "",
                    )
                    or ""
                ),

                crowd_level=str(
                    data.get(
                        "crowd_level",
                        "",
                    )
                    or ""
                ),

                safety_level=str(
                    data.get(
                        "safety_level",
                        "",
                    )
                    or ""
                ),

                music_type=str(
                    data.get(
                        "music_type",
                        "",
                    )
                    or ""
                ),

                queue_length=str(
                    data.get(
                        "queue_length",
                        "",
                    )
                    or ""
                ),

                yiyo_status=str(
                    data.get(
                        "yiyo_status",
                        "",
                    )
                    or ""
                ),

                parking_availability=str(
                    data.get(
                        "parking_availability",
                        "",
                    )
                    or ""
                ),

                parking_safety=str(
                    data.get(
                        "parking_safety",
                        "",
                    )
                    or ""
                ),

                parking_note=str(
                    data.get(
                        "parking_note",
                        "",
                    )
                    or ""
                ),

                comment=str(
                    data.get(
                        "comment",
                        "",
                    )
                    or ""
                ),

                reported_at=str(
                    data.get(
                        "reported_at",
                        "",
                    )
                    or ""
                ),

                created_at_unix=int(
                    data.get(
                        "created_at_unix",
                        0,
                    )
                    or 0
                ),

                status=str(
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