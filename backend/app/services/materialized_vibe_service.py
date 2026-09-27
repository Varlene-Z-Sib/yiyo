from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore_v1.base_query import FieldFilter

from app.firebase_config import db
from app.services.vibe_summary_service import (
    build_current_vibe_summary,
)
from app.services.yiyo_logic import (
    get_yiyo_badge_from_reports,
    is_report_active,
)


REPORTS_COLLECTION = "vibe_reports"

VENUE_COMMUNITY_SUMMARY_COLLECTION = (
    "venue_community_summary"
)

MATERIALIZED_REPORT_LIMIT = 50

MATERIALIZED_SOURCE_QUERY_LIMIT = 100

BADGE_REPORT_LIMIT = 12


def _parse_created_at_unix(
    value: Any,
) -> int | None:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None

    if parsed <= 0:
        return None

    return parsed


def _venue_id_from_venue(
    venue: dict,
) -> str:
    return str(
        venue.get("place_id")
        or venue.get("id")
        or ""
    ).strip()


def _compact_report(
    report: dict,
) -> dict:
    """
    Keep only the fields required to recalculate Current Vibe.

    No account identity, comments or moderation metadata are copied
    into the discovery cache.
    """

    return {
        "created_at_unix": (
            _parse_created_at_unix(
                report.get(
                    "created_at_unix"
                )
            )
            or 0
        ),

        "yiyo_status": str(
            report.get(
                "yiyo_status",
                "",
            )
            or ""
        ),

        "crowd_level": str(
            report.get(
                "crowd_level",
                "",
            )
            or ""
        ),

        "safety_level": str(
            report.get(
                "safety_level",
                "",
            )
            or ""
        ),

        "music_type": str(
            report.get(
                "music_type",
                "",
            )
            or ""
        ),

        "queue_length": str(
            report.get(
                "queue_length",
                "",
            )
            or ""
        ),

        "parking_availability": str(
            report.get(
                "parking_availability",
                "",
            )
            or ""
        ),

        "parking_safety": str(
            report.get(
                "parking_safety",
                "",
            )
            or ""
        ),
    }


def _sort_reports_newest_first(
    reports: list[dict],
) -> list[dict]:
    return sorted(
        reports,
        key=lambda report: (
            _parse_created_at_unix(
                report.get(
                    "created_at_unix"
                )
            )
            or 0
        ),
        reverse=True,
    )


def build_materialized_summary_document(
    venue_id: str,
    reports: list[dict],
    now: datetime | None = None,
) -> dict:
    current_time = (
        now
        or datetime.now(
            timezone.utc
        )
    )

    active_reports = [
        report
        for report in reports
        if is_report_active(
            report
        )
    ]

    active_reports = (
        _sort_reports_newest_first(
            active_reports
        )
    )

    compact_reports = []

    for report in active_reports:
        created_at_unix = (
            _parse_created_at_unix(
                report.get(
                    "created_at_unix"
                )
            )
        )

        if created_at_unix is None:
            continue

        compact_reports.append(
            _compact_report(
                report
            )
        )

        if (
            len(compact_reports)
            >= MATERIALIZED_REPORT_LIMIT
        ):
            break

    current_summary = (
        build_current_vibe_summary(
            compact_reports,
            now=current_time,
        )
    )

    yiyo_badge = (
        get_yiyo_badge_from_reports(
            compact_reports[
                :BADGE_REPORT_LIMIT
            ],
            now=current_time,
        )
    )

    return {
        "venue_id":
            venue_id,

        "recent_reports":
            compact_reports,

        "yiyo_badge":
            yiyo_badge,

        "summary":
            current_summary.model_dump(),

        "source_report_count":
            len(compact_reports),

        "calculated_at":
            current_time.isoformat(),

        "calculated_at_unix":
            int(
                current_time.timestamp()
            ),
    }


def current_state_from_materialized_document(
    document: dict | None,
    now: datetime | None = None,
) -> dict:
    """
    Recalculate freshness from the embedded compact reports.

    Cached values are not blindly trusted because reports naturally
    stop being Current Vibe after 24 hours.
    """

    if not document:
        empty_summary = (
            build_current_vibe_summary(
                [],
                now=now,
            )
        )

        return {
            "yiyo_badge":
                "MID",

            "summary":
                empty_summary,
        }

    raw_reports = document.get(
        "recent_reports",
        [],
    )

    if not isinstance(
        raw_reports,
        list,
    ):
        raw_reports = []

    reports = [
        report
        for report in raw_reports
        if isinstance(
            report,
            dict,
        )
    ]

    reports = (
        _sort_reports_newest_first(
            reports
        )
    )

    current_summary = (
        build_current_vibe_summary(
            reports,
            now=now,
        )
    )

    yiyo_badge = (
        get_yiyo_badge_from_reports(
            reports[
                :BADGE_REPORT_LIMIT
            ],
            now=now,
        )
    )

    return {
        "yiyo_badge":
            yiyo_badge,

        "summary":
            current_summary,
    }


def rebuild_venue_community_summary(
    venue_id: str,
) -> dict:
    """
    Rebuild one venue's derived cache from source vibe reports.
    """

    docs = (
        db.collection(
            REPORTS_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "venue_id",
                "==",
                venue_id,
            )
        )
        .order_by(
            "created_at_unix",
            direction="DESCENDING",
        )
        .limit(
            MATERIALIZED_SOURCE_QUERY_LIMIT
        )
        .stream()
    )

    reports = [
        doc.to_dict()
        | {
            "id": doc.id
        }
        for doc in docs
    ]

    document = (
        build_materialized_summary_document(
            venue_id=venue_id,
            reports=reports,
        )
    )

    (
        db.collection(
            VENUE_COMMUNITY_SUMMARY_COLLECTION
        )
        .document(
            venue_id
        )
        .set(
            document,
            merge=False,
        )
    )

    return document


def safe_rebuild_venue_community_summary(
    venue_id: str,
) -> bool:
    """
    Best-effort derived-cache rebuild.

    A cache failure must never cause a valid contribution to fail.
    """

    try:
        rebuild_venue_community_summary(
            venue_id
        )

        return True

    except Exception as e:
        print(
            "[WARN] Failed to rebuild "
            "venue community summary "
            f"for {venue_id}: {e}"
        )

        return False


def get_materialized_community_states(
    venue_ids: list[str],
    now: datetime | None = None,
) -> dict[str, dict]:
    """
    Batch-fetch community summary documents for discovery.

    This avoids querying vibe_reports separately for every venue.
    """

    unique_ids = list(
        dict.fromkeys(
            venue_id
            for venue_id in venue_ids
            if venue_id
        )
    )

    if not unique_ids:
        return {}

    refs = [
        db.collection(
            VENUE_COMMUNITY_SUMMARY_COLLECTION
        )
        .document(
            venue_id
        )
        for venue_id in unique_ids
    ]

    snapshots = db.get_all(
        refs
    )

    raw_documents: dict[str, dict] = {}

    for snapshot in snapshots:
        if not snapshot.exists:
            continue

        raw_documents[
            snapshot.id
        ] = (
            snapshot.to_dict()
            or {}
        )

    states: dict[str, dict] = {}

    for venue_id in unique_ids:
        states[
            venue_id
        ] = (
            current_state_from_materialized_document(
                raw_documents.get(
                    venue_id
                ),
                now=now,
            )
        )

    return states


def attach_materialized_community_states(
    venues: list[dict],
    now: datetime | None = None,
) -> list[dict]:
    """
    Enrich venue discovery records with YIYO community state using
    one batched summary fetch.

    Missing summary documents safely produce MID + an empty summary.

    The existing venue dictionaries are enriched in place so current
    discovery behaviour and sorting remain unchanged.
    """

    venue_ids = [
        venue_id
        for venue in venues
        if (
            venue_id
            := _venue_id_from_venue(
                venue
            )
        )
    ]

    states = (
        get_materialized_community_states(
            venue_ids,
            now=now,
        )
    )

    for venue in venues:
        venue_id = (
            _venue_id_from_venue(
                venue
            )
        )

        state = states.get(
            venue_id
        )

        if state is None:
            state = (
                current_state_from_materialized_document(
                    None,
                    now=now,
                )
            )

        summary = state[
            "summary"
        ]

        venue[
            "yiyo_badge"
        ] = state[
            "yiyo_badge"
        ]

        venue[
            "current_vibe_summary"
        ] = (
            summary.model_dump()
        )

    return venues