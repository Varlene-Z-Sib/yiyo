import argparse
import sys
from pathlib import Path


# Allow direct execution from:
#
# backend/
# ├── app/
# └── scripts/
#     └── grant_business_membership.py
BACKEND_ROOT = Path(
    __file__
).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(BACKEND_ROOT),
    )


# Initializes Firebase Admin using YIYO's
# existing Firebase configuration.
import app.firebase_config  # noqa: E402

from firebase_admin import auth  # noqa: E402

from app.models.authorization_model import (  # noqa: E402
    MembershipRole,
)

from app.services.authorization_service import (  # noqa: E402
    grant_business_membership,
)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Grant a YIYO business membership "
            "to an existing Firebase user."
        )
    )

    parser.add_argument(
        "--email",
        required=True,
        help=(
            "Firebase Authentication "
            "email address"
        ),
    )

    parser.add_argument(
        "--role",
        required=True,
        choices=[
            MembershipRole.PROMOTER.value,
            MembershipRole.VENUE_MANAGER.value,
        ],
        help=(
            "Business membership role"
        ),
    )

    parser.add_argument(
        "--venue-id",
        required=False,
        help=(
            "Required only when granting "
            "venue_manager access"
        ),
    )

    args = parser.parse_args()

    role = MembershipRole(
        args.role
    )

    venue_id = (
        args.venue_id.strip()
        if args.venue_id
        else None
    )

    if (
        role
        == MembershipRole.VENUE_MANAGER
        and not venue_id
    ):
        parser.error(
            "--venue-id is required "
            "for venue_manager"
        )

    if (
        role
        == MembershipRole.PROMOTER
        and venue_id is not None
    ):
        parser.error(
            "--venue-id must not be used "
            "for promoter"
        )

    try:
        user = auth.get_user_by_email(
            args.email
        )

    except Exception as error:
        print()
        print(
            "Failed to find Firebase user."
        )
        print(
            f"Email: {args.email}"
        )
        print(
            f"Error: {error}"
        )
        print()

        raise SystemExit(
            1
        )

    try:
        membership = (
            grant_business_membership(
                user_id=user.uid,
                role=role,
                venue_id=venue_id,
            )
        )

    except Exception as error:
        print()
        print(
            "Failed to grant "
            "business membership."
        )
        print(
            f"Error: {error}"
        )
        print()

        raise SystemExit(
            1
        )

    print()
    print(
        "YIYO business membership granted:"
    )
    print()

    print(
        f"membership_id="
        f"{membership.id}"
    )

    print(
        f"uid="
        f"{membership.user_id}"
    )

    print(
        f"email="
        f"{user.email}"
    )

    print(
        f"role="
        f"{membership.role.value}"
    )

    print(
        f"status="
        f"{membership.status.value}"
    )

    print(
        f"venue_id="
        f"{membership.venue_id or '<none>'}"
    )

    print()

    print(
        "The membership is stored in "
        "Firestore and will be used the "
        "next time YIYO calculates this "
        "user's effective permissions."
    )


if __name__ == "__main__":
    main()