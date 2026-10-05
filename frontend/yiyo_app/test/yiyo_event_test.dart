import 'package:flutter_test/flutter_test.dart';

import 'package:yiyo_app/models/yiyo_event.dart';


void main() {
  test(
    'parses YIYO event response',
    () {
      final event =
          YiyoEvent.fromJson(
        {
          "id":
              "event_123",

          "title":
              "Friday Night Live",

          "description":
              "Launch night",

          "venue_id":
              "venue_123",

          "venue_name":
              "Kopano Lounge",

          "venue_address":
              "Gauteng",

          "venue_lat":
              -26.10,

          "venue_lng":
              27.83,

          "organizer_uid":
              "user_123",

          "status":
              "published",

          "starts_at":
              "2026-10-02T18:00:00+00:00",

          "starts_at_unix":
              1790964000,

          "ends_at":
              null,

          "ends_at_unix":
              null,

          "poster_url":
              null,

          "ticket_url":
              null,

          "tags": [
            "Amapiano",
            "Friday",
          ],

          "hype_count":
              42,

          "going_count":
              18,

          "created_at":
              "2026-10-01T06:00:00+00:00",

          "created_at_unix":
              1790834400,
        },
      );

      expect(
        event.id,
        "event_123",
      );

      expect(
        event.title,
        "Friday Night Live",
      );

      expect(
        event.venueName,
        "Kopano Lounge",
      );

      expect(
        event.hypeCount,
        42,
      );

      expect(
        event.goingCount,
        18,
      );

      expect(
        event.tags,
        [
          "Amapiano",
          "Friday",
        ],
      );

      expect(
        event.isPublished,
        isTrue,
      );

      expect(
        event.hasPoster,
        isFalse,
      );
    },
  );


  test(
    'handles optional event fields',
    () {
      final event =
          YiyoEvent.fromJson(
        {
          "id":
              "event_123",

          "title":
              "Test",

          "venue_id":
              "venue_123",

          "venue_name":
              "Test Venue",

          "organizer_uid":
              "user_123",

          "status":
              "published",

          "starts_at_unix":
              1790964000,

          "created_at_unix":
              1790834400,
        },
      );

      expect(
        event.posterUrl,
        isNull,
      );

      expect(
        event.ticketUrl,
        isNull,
      );

      expect(
        event.endsAt,
        isNull,
      );

      expect(
        event.tags,
        isEmpty,
      );
    },
  );
}