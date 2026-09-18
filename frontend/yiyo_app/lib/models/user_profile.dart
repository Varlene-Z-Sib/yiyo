class UserProfile {
  final String uid;
  final String email;
  final String displayName;

  final int reportCount;
  final String contributorLevel;

  final String? createdAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.reportCount,
    required this.contributorLevel,
    required this.createdAt,
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserProfile(
      uid: (json["uid"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      displayName:
          (json["display_name"] ?? "").toString(),
      reportCount:
          (json["report_count"] as num?)?.toInt() ?? 0,
      contributorLevel:
          (json["contributor_level"] ?? "Rookie").toString(),
      createdAt: json["created_at"]?.toString(),
    );
  }

  String get displayLabel {
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    if (email.trim().isNotEmpty) {
      return email.trim();
    }

    return "YIYO member";
  }
}