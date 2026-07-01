class VibeReport {
  final String id;
  final String venueId;
  final String venueName;
  final String crowdLevel;
  final String safetyLevel;
  final String musicType;
  final String queueLength;
  final String yiyoStatus;
  final String comment;
  final String reportedAt;

  VibeReport({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.crowdLevel,
    required this.safetyLevel,
    required this.musicType,
    required this.queueLength,
    required this.yiyoStatus,
    required this.comment,
    required this.reportedAt,
  });

  factory VibeReport.fromJson(Map<String, dynamic> json) {
    return VibeReport(
      id: (json["id"] ?? "").toString(),
      venueId: (json["venue_id"] ?? "").toString(),
      venueName: (json["venue_name"] ?? "").toString(),
      crowdLevel: (json["crowd_level"] ?? "").toString(),
      safetyLevel: (json["safety_level"] ?? "").toString(),
      musicType: (json["music_type"] ?? "").toString(),
      queueLength: (json["queue_length"] ?? "").toString(),
      yiyoStatus: (json["yiyo_status"] ?? "").toString(),
      comment: (json["comment"] ?? "").toString(),
      reportedAt: (json["reported_at"] ?? "").toString(),
    );
  }
}