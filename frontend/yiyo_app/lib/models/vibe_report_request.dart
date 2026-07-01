class VibeReportRequest {
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

  VibeReportRequest({
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
  });

  Map<String, dynamic> toJson() {
    return {
      "venue_id": venueId,
      "venue_name": venueName,
      "crowd_level": crowdLevel,
      "safety_level": safetyLevel,
      "music_type": musicType,
      "queue_length": queueLength,
      "yiyo_status": yiyoStatus,
      "parking_availability": parkingAvailability,
      "parking_safety": parkingSafety,
      "parking_note": parkingNote,
      "comment": comment,
      "reported_at": reportedAt,
    };
  }
}