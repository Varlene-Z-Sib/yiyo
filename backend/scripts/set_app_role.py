import argparse
import sys
from pathlib import Path


# Make the backend root importable when this file is run directly:
#
# backend/
# ├── app/
# └── scripts/
#     └── set_app_role.py
BACKEND_ROOT = Path(
    __file__
).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(BACKEND_ROOT),
    )


# Importing firebase_config initializes Firebase Admin
# using YIYO's existing configuration.
import app.firebase_config  # noqa: E402

from firebase_admin import auth  # noqa: E402


VALID_ROLES = {
    "user",
    "moderator",
    "super_admin",
}


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Set a YIYO application role "
            "using Firebase custom claims."
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
        choices=sorted(
            VALID_ROLES
        ),
        help=(
            "YIYO global application role"
        ),
    )

    args = parser.parse_args()

    user = auth.get_user_by_email(
        args.email
    )

    existing_claims = (
        user.custom_claims
        or {}
    )

    new_claims = {
        **existing_claims,
        "app_role":
            args.role,
    }

    auth.set_custom_user_claims(
        user.uid,
        new_claims,
    )

    print()
    print(
        "Updated YIYO role:"
    )
    print(
        f"uid={user.uid}"
    )
    print(
        f"email={user.email}"
    )
    print(
        f"app_role={args.role}"
    )
    print()

    print(
        "The user must sign out and "
        "sign back in to YIYO so Firebase "
        "issues a fresh ID token containing "
        "the new role."
    )


if __name__ == "__main__":
    main()