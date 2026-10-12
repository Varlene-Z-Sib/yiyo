class ModerationQueue {
  final List<CommunityModerationCase>
      community;

  final List<EventModerationCase>
      events;

  final int communityCount;
  final int eventCount;
  final int totalCount;

  const ModerationQueue({
    required this.community,
    required this.events,
    required this.communityCount,
    required this.eventCount,
    required this.totalCount,
  });

  factory ModerationQueue.fromJson(
    Map<String, dynamic> json,
  ) {
    final communityJson =
        json["community"]
                as List<dynamic>? ??
            const [];

    final eventsJson =
        json["events"]
                as List<dynamic>? ??
            const [];

    return ModerationQueue(
      community:
          communityJson
              .whereType<
                  Map<String, dynamic>>()
              .map(
                CommunityModerationCase
                    .fromJson,
              )
              .toList(),

      events:
          eventsJson
              .whereType<
                  Map<String, dynamic>>()
              .map(
                EventModerationCase
                    .fromJson,
              )
              .toList(),

      communityCount:
          _asInt(
        json["community_count"],
      ),

      eventCount:
          _asInt(
        json["event_count"],
      ),

      totalCount:
          _asInt(
        json["total_count"],
      ),
    );
  }
}


class CommunityModerationCase {
  final String reportId;
  final String venueId;

  final String status;

  final String yiyoStatus;
  final String crowdLevel;
  final String safetyLevel;
  final String musicType;
  final String queueLength;

  final String parkingAvailability;
  final String parkingSafety;
  final String parkingNote;

  final String comment;

  final String createdAt;
  final int createdAtUnix;

  final int flagCount;

  final Map<String, int>
      reasons;

  final List<String>
      details;

  final String latestFlaggedAt;
  final int latestFlaggedAtUnix;

  const CommunityModerationCase({
    required this.reportId,
    required this.venueId,
    required this.status,
    required this.yiyoStatus,
    required this.crowdLevel,
    required this.safetyLevel,
    required this.musicType,
    required this.queueLength,
    required this.parkingAvailability,
    required this.parkingSafety,
    required this.parkingNote,
    required this.comment,
    required this.createdAt,
    required this.createdAtUnix,
    required this.flagCount,
    required this.reasons,
    required this.details,
    required this.latestFlaggedAt,
    required this.latestFlaggedAtUnix,
  });

  factory CommunityModerationCase.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityModerationCase(
      reportId:
          _asString(
        json["report_id"],
      ),

      venueId:
          _asString(
        json["venue_id"],
      ),

      status:
          _asString(
        json["status"],
      ),

      yiyoStatus:
          _asString(
        json["yiyo_status"],
      ),

      crowdLevel:
          _asString(
        json["crowd_level"],
      ),

      safetyLevel:
          _asString(
        json["safety_level"],
      ),

      musicType:
          _asString(
        json["music_type"],
      ),

      queueLength:
          _asString(
        json["queue_length"],
      ),

      parkingAvailability:
          _asString(
        json["parking_availability"],
      ),

      parkingSafety:
          _asString(
        json["parking_safety"],
      ),

      parkingNote:
          _asString(
        json["parking_note"],
      ),

      comment:
          _asString(
        json["comment"],
      ),

      createdAt:
          _asString(
        json["created_at"],
      ),

      createdAtUnix:
          _asInt(
        json["created_at_unix"],
      ),

      flagCount:
          _asInt(
        json["flag_count"],
      ),

      reasons:
          _parseReasons(
        json["reasons"],
      ),

      details:
          _parseStringList(
        json["details"],
      ),

      latestFlaggedAt:
          _asString(
        json["latest_flagged_at"],
      ),

      latestFlaggedAtUnix:
          _asInt(
        json["latest_flagged_at_unix"],
      ),
    );
  }
}


class EventModerationCase {
  final String eventId;

  final String title;
  final String description;

  final String venueId;
  final String venueName;

  final String status;

  final String startsAt;
  final int startsAtUnix;

  final String createdAt;
  final int createdAtUnix;

  final int flagCount;

  final Map<String, int>
      reasons;

  final List<String>
      details;

  final String latestFlaggedAt;
  final int latestFlaggedAtUnix;

  const EventModerationCase({
    required this.eventId,
    required this.title,
    required this.description,
    required this.venueId,
    required this.venueName,
    required this.status,
    required this.startsAt,
    required this.startsAtUnix,
    required this.createdAt,
    required this.createdAtUnix,
    required this.flagCount,
    required this.reasons,
    required this.details,
    required this.latestFlaggedAt,
    required this.latestFlaggedAtUnix,
  });

  factory EventModerationCase.fromJson(
    Map<String, dynamic> json,
  ) {
    return EventModerationCase(
      eventId:
          _asString(
        json["event_id"],
      ),

      title:
          _asString(
        json["title"],
      ),

      description:
          _asString(
        json["description"],
      ),

      venueId:
          _asString(
        json["venue_id"],
      ),

      venueName:
          _asString(
        json["venue_name"],
      ),

      status:
          _asString(
        json["status"],
      ),

      startsAt:
          _asString(
        json["starts_at"],
      ),

      startsAtUnix:
          _asInt(
        json["starts_at_unix"],
      ),

      createdAt:
          _asString(
        json["created_at"],
      ),

      createdAtUnix:
          _asInt(
        json["created_at_unix"],
      ),

      flagCount:
          _asInt(
        json["flag_count"],
      ),

      reasons:
          _parseReasons(
        json["reasons"],
      ),

      details:
          _parseStringList(
        json["details"],
      ),

      latestFlaggedAt:
          _asString(
        json["latest_flagged_at"],
      ),

      latestFlaggedAtUnix:
          _asInt(
        json["latest_flagged_at_unix"],
      ),
    );
  }
}


String _asString(
  dynamic value,
) {
  return (
    value ??
    ""
  ).toString().trim();
}


int _asInt(
  dynamic value,
) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ??
            "",
      ) ??
      0;
}


Map<String, int> _parseReasons(
  dynamic value,
) {
  if (value
      is! Map) {
    return const {};
  }

  final result =
      <String, int>{};

  for (
    final entry
        in value.entries
  ) {
    final key =
        entry.key
            .toString()
            .trim();

    if (key.isEmpty) {
      continue;
    }

    result[key] =
        _asInt(
      entry.value,
    );
  }

  return result;
}


List<String> _parseStringList(
  dynamic value,
) {
  if (value
      is! List) {
    return const [];
  }

  return value
      .map(
        (item) =>
            item
                .toString()
                .trim(),
      )
      .where(
        (item) =>
            item.isNotEmpty,
      )
      .toList();
}