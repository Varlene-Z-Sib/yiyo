class UserContribution {
  final String id;

  final String venueId;
  final String venueName;

  final String crowdLevel;
  final String safetyLevel;
  final String musicType;
  final String queueLength;
  final String yiyoStatus;

  final String parkingAvailability;
  final String parkingSafety;
  final String parkingNote;

  final String comment;

  final String reportedAt;
  final int createdAtUnix;

  final String status;

  const UserContribution({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.crowdLevel,
    required this.safetyLevel,
    required this.musicType,
    required this.queueLength,
    required this.yiyoStatus,
    required this.parkingAvailability,
    required this.parkingSafety,
    required this.parkingNote,
    required this.comment,
    required this.reportedAt,
    required this.createdAtUnix,
    required this.status,
  });

  factory UserContribution.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserContribution(
      id: (json["id"] ?? "").toString(),
      venueId:
          (json["venue_id"] ?? "").toString(),
      venueName:
          (json["venue_name"] ?? "").toString(),
      crowdLevel:
          (json["crowd_level"] ?? "").toString(),
      safetyLevel:
          (json["safety_level"] ?? "").toString(),
      musicType:
          (json["music_type"] ?? "").toString(),
      queueLength:
          (json["queue_length"] ?? "").toString(),
      yiyoStatus:
          (json["yiyo_status"] ?? "").toString(),
      parkingAvailability:
          (json["parking_availability"] ?? "").toString(),
      parkingSafety:
          (json["parking_safety"] ?? "").toString(),
      parkingNote:
          (json["parking_note"] ?? "").toString(),
      comment:
          (json["comment"] ?? "").toString(),
      reportedAt:
          (json["reported_at"] ?? "").toString(),
      createdAtUnix:
          (json["created_at_unix"] as num?)?.toInt() ?? 0,
      status:
          (json["status"] ?? "active").toString(),
    );
  }

  DateTime? get reportedDateTime {
    if (createdAtUnix > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        createdAtUnix * 1000,
        isUtc: true,
      );
    }

    return DateTime.tryParse(
      reportedAt,
    )?.toUtc();
  }

  String freshnessLabel({
    DateTime? now,
  }) {
    final reportTime = reportedDateTime;

    if (reportTime == null) {
      return "Time unavailable";
    }

    final currentTime =
        (now ?? DateTime.now()).toUtc();

    final difference =
        currentTime.difference(reportTime);

    if (difference.isNegative ||
        difference.inMinutes < 1) {
      return "Just now";
    }

    if (difference.inMinutes < 60) {
      final minutes =
          difference.inMinutes;

      return "$minutes "
          "min${minutes == 1 ? "" : "s"} ago";
    }

    if (difference.inHours < 24) {
      final hours =
          difference.inHours;

      return "$hours "
          "hr${hours == 1 ? "" : "s"} ago";
    }

    final days = difference.inDays;

    return "$days "
        "day${days == 1 ? "" : "s"} ago";
  }

  bool get isUnderReview {
    return status.toLowerCase() == "flagged";
  }

  bool get isRemoved {
    return status.toLowerCase() == "removed";
  }
}