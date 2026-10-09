class ManagedVenueAccess {
  final String id;

  final String name;

  final String address;


  const ManagedVenueAccess({
    required this.id,
    required this.name,
    required this.address,
  });


  factory ManagedVenueAccess.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagedVenueAccess(
      id:
          (json["id"] ?? "")
              .toString(),

      name:
          (json["name"] ?? "")
              .toString(),

      address:
          (json["address"] ?? "")
              .toString(),
    );
  }
}


class ProfileAccessSummary {
  final bool promoter;

  final bool venueManager;

  final bool superAdmin;

  final List<ManagedVenueAccess>
      managedVenues;


  const ProfileAccessSummary({
    required this.promoter,
    required this.venueManager,
    required this.superAdmin,
    required this.managedVenues,
  });


  factory ProfileAccessSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final venues =
        json["managed_venues"]
                as List<dynamic>? ??
            [];

    return ProfileAccessSummary(
      promoter:
          json["promoter"] == true,

      venueManager:
          json["venue_manager"] == true,

      superAdmin:
          json["super_admin"] == true,

      managedVenues:
          venues
              .map(
                (item) =>
                    ManagedVenueAccess
                        .fromJson(
                  item as Map<
                      String,
                      dynamic>,
                ),
              )
              .toList(),
    );
  }


  static const empty =
      ProfileAccessSummary(
    promoter: false,
    venueManager: false,
    superAdmin: false,
    managedVenues: [],
  );


  bool get hasBusinessAccess =>
      promoter ||
      venueManager ||
      superAdmin;
}