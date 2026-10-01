class VibeReportRequest {
  final String venueId;
  final String venueName;

  // Quick Vibe required fields.
  final String crowdLevel;
  final String yiyoStatus;

  // Optional detailed fields.
  final String? safetyLevel;
  final String? musicType;
  final String? queueLength;

  final String? parkingAvailability;
  final String? parkingSafety;

  final String parkingNote;
  final String comment;

  // Retained for compatibility.
  // The backend remains authoritative for report time.
  final String? reportedAt;

  const VibeReportRequest({
    required this.venueId,
    required this.venueName,
    required this.crowdLevel,
    required this.yiyoStatus,
    this.safetyLevel,
    this.musicType,
    this.queueLength,
    this.parkingAvailability,
    this.parkingSafety,
    this.parkingNote = "",
    this.comment = "",
    this.reportedAt,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      "venue_id": venueId,
      "venue_name": venueName,
      "crowd_level": crowdLevel,
      "yiyo_status": yiyoStatus,
    };

    if (safetyLevel != null) {
      json["safety_level"] =
          safetyLevel;
    }

    if (musicType != null) {
      json["music_type"] =
          musicType;
    }

    if (queueLength != null) {
      json["queue_length"] =
          queueLength;
    }

    if (parkingAvailability != null) {
      json["parking_availability"] =
          parkingAvailability;
    }

    if (parkingSafety != null) {
      json["parking_safety"] =
          parkingSafety;
    }

    if (parkingNote.trim().isNotEmpty) {
      json["parking_note"] =
          parkingNote.trim();
    }

    if (comment.trim().isNotEmpty) {
      json["comment"] =
          comment.trim();
    }

    if (reportedAt != null &&
        reportedAt!.trim().isNotEmpty) {
      json["reported_at"] =
          reportedAt!.trim();
    }

    return json;
  }
}