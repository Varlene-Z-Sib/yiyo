class AppPermissions {
  final String uid;
  final String appRole;

  final bool isPromoter;
  final List<String> managedVenueIds;

  final bool moderateContent;
  final bool superAdmin;

  final bool createEvents;
  final bool manageVenues;

  const AppPermissions({
    required this.uid,
    required this.appRole,
    required this.isPromoter,
    required this.managedVenueIds,
    required this.moderateContent,
    required this.superAdmin,
    required this.createEvents,
    required this.manageVenues,
  });

  factory AppPermissions.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppPermissions(
      uid:
          (json["uid"] ?? "")
              .toString(),

      appRole:
          (json["app_role"] ?? "user")
              .toString(),

      isPromoter:
          json["is_promoter"] == true,

      managedVenueIds:
          _parseStringList(
        json["managed_venue_ids"],
      ),

      moderateContent:
          json["moderate_content"] ==
              true,

      superAdmin:
          json["super_admin"] == true,

      createEvents:
          json["create_events"] ==
              true,

      manageVenues:
          json["manage_venues"] ==
              true,
    );
  }

  static List<String> _parseStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
          (item) =>
              item.toString().trim(),
        )
        .where(
          (item) =>
              item.isNotEmpty,
        )
        .toList();
  }
}