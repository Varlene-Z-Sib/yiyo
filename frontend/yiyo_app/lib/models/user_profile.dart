class UserProfile {
  final String uid;
  final String email;

  final String username;
  final String fullName;

  // Temporary backward-compatible field.
  final String displayName;

  final bool profileComplete;

  final int reportCount;
  final String contributorLevel;

  final String? createdAt;

  final String termsVersion;
  final String privacyVersion;
  final String? legalAcceptedAt;
  final bool legalAcceptanceCurrent;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    required this.displayName,
    required this.profileComplete,
    required this.reportCount,
    required this.contributorLevel,
    required this.createdAt,
    required this.termsVersion,
    required this.privacyVersion,
    required this.legalAcceptedAt,
    required this.legalAcceptanceCurrent,
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserProfile(
      uid:
          (json["uid"] ?? "")
              .toString(),

      email:
          (json["email"] ?? "")
              .toString(),

      username:
          (json["username"] ?? "")
              .toString(),

      fullName:
          (json["full_name"] ?? "")
              .toString(),

      displayName:
          (json["display_name"] ?? "")
              .toString(),

      profileComplete:
          json["profile_complete"] ==
              true,

      reportCount:
          (json["report_count"]
                      as num?)
                  ?.toInt() ??
              0,

      contributorLevel:
          (json["contributor_level"] ??
                  "Rookie")
              .toString(),

      createdAt:
          json["created_at"]
              ?.toString(),

      termsVersion:
          (json["terms_version"] ?? "")
              .toString(),

      privacyVersion:
          (json["privacy_version"] ?? "")
              .toString(),

      legalAcceptedAt:
          json["legal_accepted_at"]
              ?.toString(),

      legalAcceptanceCurrent:
          json["legal_acceptance_current"] ==
              true,
    );
  }

  String get usernameLabel {
    final clean =
        username.trim();

    if (clean.isEmpty) {
      return "";
    }

    return "@$clean";
  }

  String get displayLabel {
    if (username.trim().isNotEmpty) {
      return username.trim();
    }

    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    if (email.trim().isNotEmpty) {
      return email.trim();
    }

    return "YIYO member";
  }
}