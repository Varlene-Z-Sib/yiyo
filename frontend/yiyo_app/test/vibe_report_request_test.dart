import 'package:flutter_test/flutter_test.dart';
import 'package:yiyo_app/models/vibe_report_request.dart';

void main() {
  test('VibeReportRequest serializes correctly for the API', () {
    final report = VibeReportRequest(
      venueId: 'venue_123',
      venueName: 'Test Lounge',
      crowdLevel: 'Busy',
      safetyLevel: 'Safe',
      musicType: 'Amapiano',
      queueLength: 'Short',
      yiyoStatus: 'YIYO',
      parkingAvailability: 'Available',
      parkingSafety: 'Safe',
      parkingNote: 'Parking behind the venue',
      comment: 'Good energy tonight',
      reportedAt: '2026-09-17T20:30:00',
    );

    final json = report.toJson();

    expect(json['venue_id'], 'venue_123');
    expect(json['venue_name'], 'Test Lounge');
    expect(json['crowd_level'], 'Busy');
    expect(json['safety_level'], 'Safe');
    expect(json['music_type'], 'Amapiano');
    expect(json['queue_length'], 'Short');
    expect(json['yiyo_status'], 'YIYO');
    expect(json['parking_availability'], 'Available');
    expect(json['parking_safety'], 'Safe');
    expect(json['parking_note'], 'Parking behind the venue');
    expect(json['comment'], 'Good energy tonight');
    expect(json['reported_at'], '2026-09-17T20:30:00');
  });
}