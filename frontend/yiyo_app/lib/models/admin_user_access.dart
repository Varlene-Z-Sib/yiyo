class AdminVenueOption {
  final String id;

  final String name;

  final String address;


  const AdminVenueOption({
    required this.id,
    required this.name,
    required this.address,
  });


  factory AdminVenueOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminVenueOption(
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

class AdminMembership {
  final String id;
  final String userId;
  final String role;
  final String? venueId;
  final String status;
  final String? venueName;


  const AdminMembership({
    required this.id,
    required this.userId,
    required this.role,
    required this.venueId,
    required this.status,
    required this.venueName,
  });


  factory AdminMembership.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawVenueName =
    json["venue_name"]
        ?.toString()
        .trim();

    final rawVenue =
        json["venue_id"]
            ?.toString()
            .trim();

    return AdminMembership(
      id:
          (json["id"] ?? "")
              .toString(),

      userId:
          (json["user_id"] ?? "")
              .toString(),

      role:
          (json["role"] ?? "")
              .toString(),

      venueId:
          rawVenue == null ||
                  rawVenue.isEmpty
              ? null
              : rawVenue,

      status:
          (json["status"] ?? "")
              .toString(),

      venueName:
          rawVenueName == null ||
                  rawVenueName.isEmpty
              ? null
              : rawVenueName,
          );
  }


  bool get isActive =>
      status == "active";

  bool get isPromoter =>
      role == "promoter";

  bool get isVenueManager =>
      role == "venue_manager";
}


class AdminUserAccess {
  final String uid;

  final String username;

  final String fullName;

  final String email;

  final List<AdminMembership>
      memberships;


  const AdminUserAccess({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.email,
    required this.memberships,
  });


  factory AdminUserAccess.fromJson(
    Map<String, dynamic> json,
  ) {
    final membershipsJson =
        json["memberships"]
                as List<dynamic>? ??
            [];

    return AdminUserAccess(
      uid:
          (json["uid"] ?? "")
              .toString(),

      username:
          (json["username"] ?? "")
              .toString(),

      fullName:
          (json["full_name"] ?? "")
              .toString(),

      email:
          (json["email"] ?? "")
              .toString(),

      memberships:
          membershipsJson
              .map(
                (item) =>
                    AdminMembership
                        .fromJson(
                  item as Map<
                      String,
                      dynamic>,
                ),
              )
              .toList(),
    );
  }


  AdminMembership?
      get activePromoter {
    for (final membership
        in memberships) {
      if (
          membership.isPromoter &&
          membership.isActive) {
        return membership;
      }
    }

    return null;
  }


  List<AdminMembership>
      get venueManagerMemberships {
    return memberships
        .where(
          (membership) =>
              membership
                  .isVenueManager,
        )
        .toList();
  }


  String get usernameLabel {
    if (username.trim().isEmpty) {
      return "No username";
    }

    return "@$username";
  }
}