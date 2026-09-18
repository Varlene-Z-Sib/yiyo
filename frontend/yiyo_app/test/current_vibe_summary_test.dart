import 'package:flutter_test/flutter_test.dart';
import 'package:yiyo_app/models/current_vibe_summary.dart';

void main() {
  test(
    'empty summary has no current reports',
    () {
      final summary =
          CurrentVibeSummary.empty();

      expect(
        summary.reportCount,
        0,
      );

      expect(
        summary.hasCurrentReports,
        isFalse,
      );

      expect(
        summary.crowd.value,
        isNull,
      );
    },
  );

  test(
    'summary parses consensus signals',
    () {
      final summary =
          CurrentVibeSummary.fromJson({
        'report_count': 4,
        'latest_created_at_unix':
            1789732800,

        'crowd': {
          'value': 'Busy',
          'agreement_count': 3,
        },

        'safety': {
          'value': 'Safe',
          'agreement_count': 3,
        },

        'music': {
          'value': 'Amapiano',
          'agreement_count': 2,
        },

        'queue': {
          'value': 'Short',
          'agreement_count': 2,
        },

        'parking_availability': {
          'value': 'Available',
          'agreement_count': 2,
        },

        'parking_safety': {
          'value': 'Safe',
          'agreement_count': 2,
        },
      });

      expect(
        summary.reportCount,
        4,
      );

      expect(
        summary.crowd.value,
        'Busy',
      );

      expect(
        summary.crowd.agreementCount,
        3,
      );

      expect(
        summary.safety.value,
        'Safe',
      );
    },
  );

  test(
    'signal detects whether it has a value',
    () {
      const populated =
          CurrentVibeSignal(
        value: 'Busy',
        agreementCount: 2,
      );

      const empty =
          CurrentVibeSignal(
        value: null,
        agreementCount: 0,
      );

      expect(
        populated.hasValue,
        isTrue,
      );

      expect(
        empty.hasValue,
        isFalse,
      );
    },
  );

  test(
    'summary creates freshness label',
    () {
      final now = DateTime.utc(
        2026,
        9,
        18,
        12,
      );

      final latest = DateTime.utc(
        2026,
        9,
        18,
        11,
        30,
      );

      final summary =
          CurrentVibeSummary(
        reportCount: 3,
        latestCreatedAtUnix:
            latest.millisecondsSinceEpoch ~/
                1000,
        crowd:
            const CurrentVibeSignal(
          value: 'Busy',
          agreementCount: 2,
        ),
        safety:
            const CurrentVibeSignal(
          value: 'Safe',
          agreementCount: 2,
        ),
        music:
            const CurrentVibeSignal(
          value: 'Amapiano',
          agreementCount: 2,
        ),
        queue:
            const CurrentVibeSignal(
          value: 'Short',
          agreementCount: 2,
        ),
        parkingAvailability:
            const CurrentVibeSignal(
          value: 'Available',
          agreementCount: 1,
        ),
        parkingSafety:
            const CurrentVibeSignal(
          value: 'Safe',
          agreementCount: 1,
        ),
      );

      expect(
        summary.freshnessLabel(
          now: now,
        ),
        'Updated 30 mins ago',
      );
    },
  );
}