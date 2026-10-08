import argparse
import sys

from collections import Counter
from pathlib import Path


# Allow this script to be run directly from:
#
# backend/
# python .\scripts\backfill_user_report_stats.py
#
# without hitting:
# ModuleNotFoundError: No module named 'app'
BACKEND_ROOT = Path(
    __file__
).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(BACKEND_ROOT),
    )


from app.firebase_config import db  # noqa: E402
from app.services.yiyo_logic import (  # noqa: E402
    contributor_level_from_count,
)


USERS_COLLECTION = "users"
REPORTS_COLLECTION = "vibe_reports"

BATCH_SIZE = 400


def collect_report_counts() -> tuple[
    Counter,
    int,
]:
    counts = Counter()

    skipped_without_uid = 0

    docs = (
        db.collection(
            REPORTS_COLLECTION
        )
        .stream()
    )

    for doc in docs:
        data = (
            doc.to_dict()
            or {}
        )

        uid = str(
            data.get(
                "uid",
                "",
            )
            or ""
        ).strip()

        if not uid:
            skipped_without_uid += 1
            continue

        # Count historical contributions.
        #
        # This intentionally counts every
        # submitted vibe report belonging
        # to the UID, including reports
        # later placed under review.
        counts[uid] += 1

    return (
        counts,
        skipped_without_uid,
    )


def load_existing_users():
    users = {}

    docs = (
        db.collection(
            USERS_COLLECTION
        )
        .stream()
    )

    for doc in docs:
        users[doc.id] = (
            doc.to_dict()
            or {}
        )

    return users


def preview_changes(
    users,
    report_counts,
):
    changes = []

    for uid, user_data in users.items():
        actual_count = int(
            report_counts.get(
                uid,
                0,
            )
        )

        stored_count = int(
            user_data.get(
                "report_count",
                0,
            )
            or 0
        )

        stored_level = str(
            user_data.get(
                "contributor_level",
                "",
            )
            or ""
        ).strip()

        actual_level = (
            contributor_level_from_count(
                actual_count
            )
        )

        if (
            stored_count != actual_count
            or stored_level != actual_level
        ):
            changes.append(
                {
                    "uid":
                        uid,

                    "old_count":
                        stored_count,

                    "new_count":
                        actual_count,

                    "old_level":
                        stored_level,

                    "new_level":
                        actual_level,
                }
            )

    return changes


def apply_changes(
    changes,
):
    if not changes:
        return

    batch = db.batch()

    pending = 0

    for change in changes:
        uid = change["uid"]

        user_ref = (
            db.collection(
                USERS_COLLECTION
            )
            .document(
                uid
            )
        )

        batch.set(
            user_ref,
            {
                "report_count":
                    change[
                        "new_count"
                    ],

                "contributor_level":
                    change[
                        "new_level"
                    ],
            },
            merge=True,
        )

        pending += 1

        if pending >= BATCH_SIZE:
            batch.commit()

            batch = db.batch()

            pending = 0

    if pending > 0:
        batch.commit()


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Backfill YIYO user report counts "
            "from existing vibe reports."
        )
    )

    parser.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Write the calculated values to "
            "Firestore. Without this flag the "
            "script performs a dry run only."
        ),
    )

    args = parser.parse_args()

    print(
        "[INFO] Reading vibe reports..."
    )

    (
        report_counts,
        skipped_without_uid,
    ) = collect_report_counts()

    print(
        "[INFO] Reading existing users..."
    )

    users = load_existing_users()

    changes = preview_changes(
        users,
        report_counts,
    )

    report_total = sum(
        report_counts.values()
    )

    print()
    print(
        "YIYO contribution backfill"
    )
    print(
        "--------------------------"
    )
    print(
        f"Existing users: {len(users)}"
    )
    print(
        f"Reports with UID: {report_total}"
    )
    print(
        "Reports without UID: "
        f"{skipped_without_uid}"
    )
    print(
        "Users requiring update: "
        f"{len(changes)}"
    )
    print()

    for change in changes:
        print(
            f"{change['uid']}: "
            f"{change['old_count']} "
            f"→ {change['new_count']} "
            f"| "
            f"{change['old_level'] or '(blank)'} "
            f"→ {change['new_level']}"
        )

    print()

    if not args.apply:
        print(
            "[DRY RUN] Nothing was written."
        )
        print(
            "Run again with --apply "
            "when the values look correct."
        )

        return

    print(
        "[INFO] Applying changes..."
    )

    apply_changes(
        changes
    )

    print(
        "[OK] Backfill complete."
    )


if __name__ == "__main__":
    main()