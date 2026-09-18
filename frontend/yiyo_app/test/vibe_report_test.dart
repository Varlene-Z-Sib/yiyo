import 'package:flutter_test/flutter_test.dart';
import 'package:yiyo_app/models/vibe_report.dart';

void main() {
  group('VibeReport', () {
    test(
      'parses report fields from API JSON',
      () {
        final report =
            VibeReport.fromJson({
          'id': 'report_123',
          'venue_id': 'venue_123',
          'venue_name': 'Test Lounge',
          'crowd_level': 'Busy',
          'safety_level': 'Safe',
          'music_type': 'Amapiano',
          'queue_length': 'Short',
          'yiyo_status':
              'Yes definitely',
          'parking_availability':
              'Available',
          'parking_safety': 'Safe',
          'parking_note':
              'Guarded parking',
          'comment': 'Good energy',
          'reported_at':
              '2026-09-17T18:00:00Z',
          'created_at_unix':
              1789668000,
        });

        expect(
          report.id,
          'report_123',
        );

        expect(
          report.venueId,
          'venue_123',
        );

        expect(
          report.crowdLevel,
          'Busy',
        );

        expect(
          report.safetyLevel,
          'Safe',
        );

        expect(
          report.parkingAvailability,
          'Available',
        );

        expect(
          report.parkingSafety,
          'Safe',
        );

        expect(
          report.parkingNote,
          'Guarded parking',
        );

        expect(
          report.createdAtUnix,
          1789668000,
        );
      },
    );

    test(
      'shows minutes for a recent report',
      () {
        final now =
            DateTime.utc(
          2026,
          9,
          17,
          18,
          30,
        );

        final report =
            VibeReport.fromJson({
          'created_at_unix':
              DateTime.utc(
                    2026,
                    9,
                    17,
                    18,
                    18,
                  )
                      .millisecondsSinceEpoch ~/
                  1000,
        });

        expect(
          report.freshnessLabel(
            now: now,
          ),
          '12 mins ago',
        );
      },
    );

    test(
      'shows hours for a report from earlier today',
      () {
        final now =
            DateTime.utc(
          2026,
          9,
          17,
          18,
        );

        final report =
            VibeReport.fromJson({
          'created_at_unix':
              DateTime.utc(
                    2026,
                    9,
                    17,
                    15,
                  )
                      .millisecondsSinceEpoch ~/
                  1000,
        });

        expect(
          report.freshnessLabel(
            now: now,
          ),
          '3 hrs ago',
        );
      },
    );

    test(
      'shows days for an older report',
      () {
        final now =
            DateTime.utc(
          2026,
          9,
          17,
        );

        final report =
            VibeReport.fromJson({
          'created_at_unix':
              DateTime.utc(
                    2026,
                    9,
                    15,
                  )
                      .millisecondsSinceEpoch ~/
                  1000,
        });

        expect(
          report.freshnessLabel(
            now: now,
          ),
          '2 days ago',
        );
      },
    );

    test(
      'report within 24 hours is current',
      () {
        final now =
            DateTime.utc(
          2026,
          9,
          18,
          12,
        );

        final report =
            VibeReport.fromJson({
          'created_at_unix':
              DateTime.utc(
                    2026,
                    9,
                    18,
                    8,
                  )
                      .millisecondsSinceEpoch ~/
                  1000,
        });

        expect(
          report.isCurrent(
            now: now,
          ),
          isTrue,
        );
      },
    );

    test(
      'report older than 24 hours is not current',
      () {
        final now =
            DateTime.utc(
          2026,
          9,
          18,
          12,
        );

        final report =
            VibeReport.fromJson({
          'created_at_unix':
              DateTime.utc(
                    2026,
                    9,
                    17,
                    10,
                  )
                      .millisecondsSinceEpoch ~/
                  1000,
        });

        expect(
          report.isCurrent(
            now: now,
          ),
          isFalse,
        );
      },
    );
  });
}