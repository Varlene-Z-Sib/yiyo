import 'package:flutter_test/flutter_test.dart';
import 'package:yiyo_app/models/user_contribution.dart';
import 'package:yiyo_app/models/user_profile.dart';

void main() {
  test(
    'UserProfile parses API response',
    () {
      final profile =
          UserProfile.fromJson({
        'uid': 'user_123',
        'email':
            'test@example.com',
        'display_name':
            'Test User',
        'report_count': 12,
        'contributor_level':
            'Active',
      });

      expect(
        profile.uid,
        'user_123',
      );

      expect(
        profile.displayName,
        'Test User',
      );

      expect(
        profile.reportCount,
        12,
      );

      expect(
        profile.contributorLevel,
        'Active',
      );
    },
  );

  test(
    'UserProfile falls back to email for display label',
    () {
      final profile =
          UserProfile.fromJson({
        'uid': 'user_123',
        'email':
            'test@example.com',
      });

      expect(
        profile.displayLabel,
        'test@example.com',
      );
    },
  );

  test(
    'UserContribution exposes moderation state',
    () {
      final contribution =
          UserContribution.fromJson({
        'id': 'report_123',
        'venue_id':
            'venue_123',
        'venue_name':
            'Test Lounge',
        'status': 'flagged',
      });

      expect(
        contribution.isUnderReview,
        isTrue,
      );

      expect(
        contribution.isRemoved,
        isFalse,
      );
    },
  );

  test(
    'UserContribution creates freshness label',
    () {
      final now =
          DateTime.utc(
        2026,
        9,
        18,
        12,
      );

      final contribution =
          UserContribution.fromJson({
        'id': 'report_123',
        'venue_id':
            'venue_123',
        'venue_name':
            'Test Lounge',
        'created_at_unix':
            DateTime.utc(
                  2026,
                  9,
                  18,
                  11,
                )
                    .millisecondsSinceEpoch ~/
                1000,
      });

      expect(
        contribution
            .freshnessLabel(
          now: now,
        ),
        '1 hr ago',
      );
    },
  );
}