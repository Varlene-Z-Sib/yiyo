import 'package:flutter_test/flutter_test.dart';

import 'package:yiyo_app/models/app_permissions.dart';


void main() {
  test(
    'parses super admin permissions',
    () {
      final permissions =
          AppPermissions.fromJson(
        {
          "uid":
              "admin_123",
          "app_role":
              "super_admin",
          "is_promoter":
              false,
          "managed_venue_ids":
              [],
          "moderate_content":
              true,
          "super_admin":
              true,
          "create_events":
              true,
          "manage_venues":
              true,
        },
      );

      expect(
        permissions.appRole,
        "super_admin",
      );

      expect(
        permissions.superAdmin,
        isTrue,
      );

      expect(
        permissions.createEvents,
        isTrue,
      );

      expect(
        permissions.moderateContent,
        isTrue,
      );
    },
  );


  test(
    'parses venue manager permissions',
    () {
      final permissions =
          AppPermissions.fromJson(
        {
          "uid":
              "user_123",
          "app_role":
              "user",
          "is_promoter":
              false,
          "managed_venue_ids":
              [
            "venue_a",
            "venue_b",
          ],
          "moderate_content":
              false,
          "super_admin":
              false,
          "create_events":
              true,
          "manage_venues":
              true,
        },
      );

      expect(
        permissions
            .managedVenueIds,
        [
          "venue_a",
          "venue_b",
        ],
      );

      expect(
        permissions.createEvents,
        isTrue,
      );

      expect(
        permissions.manageVenues,
        isTrue,
      );

      expect(
        permissions.superAdmin,
        isFalse,
      );
    },
  );
}