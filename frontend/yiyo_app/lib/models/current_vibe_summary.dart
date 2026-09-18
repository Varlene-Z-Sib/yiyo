class CurrentVibeSignal {
  final String? value;
  final int agreementCount;

  const CurrentVibeSignal({
    required this.value,
    required this.agreementCount,
  });

  factory CurrentVibeSignal.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      );
    }

    final rawValue = json["value"]?.toString().trim();

    return CurrentVibeSignal(
      value: rawValue == null || rawValue.isEmpty
          ? null
          : rawValue,
      agreementCount:
          (json["agreement_count"] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasValue {
    return value != null && value!.trim().isNotEmpty;
  }
}


class CurrentVibeSummary {
  final int reportCount;
  final int? latestCreatedAtUnix;

  final CurrentVibeSignal crowd;
  final CurrentVibeSignal safety;
  final CurrentVibeSignal music;
  final CurrentVibeSignal queue;

  final CurrentVibeSignal parkingAvailability;
  final CurrentVibeSignal parkingSafety;

  const CurrentVibeSummary({
    required this.reportCount,
    required this.latestCreatedAtUnix,
    required this.crowd,
    required this.safety,
    required this.music,
    required this.queue,
    required this.parkingAvailability,
    required this.parkingSafety,
  });

  factory CurrentVibeSummary.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return CurrentVibeSummary.empty();
    }

    return CurrentVibeSummary(
      reportCount:
          (json["report_count"] as num?)?.toInt() ?? 0,

      latestCreatedAtUnix:
          (json["latest_created_at_unix"] as num?)?.toInt(),

      crowd: CurrentVibeSignal.fromJson(
        json["crowd"] as Map<String, dynamic>?,
      ),

      safety: CurrentVibeSignal.fromJson(
        json["safety"] as Map<String, dynamic>?,
      ),

      music: CurrentVibeSignal.fromJson(
        json["music"] as Map<String, dynamic>?,
      ),

      queue: CurrentVibeSignal.fromJson(
        json["queue"] as Map<String, dynamic>?,
      ),

      parkingAvailability:
          CurrentVibeSignal.fromJson(
        json["parking_availability"]
            as Map<String, dynamic>?,
      ),

      parkingSafety:
          CurrentVibeSignal.fromJson(
        json["parking_safety"]
            as Map<String, dynamic>?,
      ),
    );
  }

  factory CurrentVibeSummary.empty() {
    return const CurrentVibeSummary(
      reportCount: 0,
      latestCreatedAtUnix: null,
      crowd: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
      safety: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
      music: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
      queue: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
      parkingAvailability: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
      parkingSafety: CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      ),
    );
  }

  bool get hasCurrentReports {
    return reportCount > 0;
  }

  DateTime? get latestReportDateTime {
    if (latestCreatedAtUnix == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      latestCreatedAtUnix! * 1000,
      isUtc: true,
    );
  }

  String freshnessLabel({
    DateTime? now,
  }) {
    final reportTime = latestReportDateTime;

    if (reportTime == null) {
      return "No recent updates";
    }

    final currentTime =
        (now ?? DateTime.now()).toUtc();

    final difference =
        currentTime.difference(reportTime);

    if (difference.isNegative ||
        difference.inMinutes < 1) {
      return "Updated just now";
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;

      return "Updated $minutes "
          "min${minutes == 1 ? "" : "s"} ago";
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;

      return "Updated $hours "
          "hr${hours == 1 ? "" : "s"} ago";
    }

    final days = difference.inDays;

    return "Updated $days "
        "day${days == 1 ? "" : "s"} ago";
  }
}