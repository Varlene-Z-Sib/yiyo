class YiyoEvent {
  final String id;

  final String title;
  final String description;

  final String venueId;
  final String venueName;
  final String venueAddress;

  final double? venueLat;
  final double? venueLng;

  final String organizerUid;
  final String status;

  final DateTime startsAt;
  final DateTime? endsAt;

  final String? posterUrl;
  final String? ticketUrl;

  final List<String> tags;

  final int hypeCount;
  final int goingCount;

  final DateTime createdAt;
  final DateTime? publishedAt;

  const YiyoEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venueId,
    required this.venueName,
    required this.venueAddress,
    required this.venueLat,
    required this.venueLng,
    required this.organizerUid,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.posterUrl,
    required this.ticketUrl,
    required this.tags,
    required this.hypeCount,
    required this.goingCount,
    required this.createdAt,
    required this.publishedAt,
  });

  factory YiyoEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return YiyoEvent(
      id:
          (json["id"] ?? "")
              .toString(),

      title:
          (json["title"] ?? "")
              .toString(),

      description:
          (json["description"] ?? "")
              .toString(),

      venueId:
          (json["venue_id"] ?? "")
              .toString(),

      venueName:
          (json["venue_name"] ?? "")
              .toString(),

      venueAddress:
          (json["venue_address"] ?? "")
              .toString(),

      venueLat:
          _parseDouble(
        json["venue_lat"],
      ),

      venueLng:
          _parseDouble(
        json["venue_lng"],
      ),

      organizerUid:
          (json["organizer_uid"] ?? "")
              .toString(),

      status:
          (json["status"] ?? "")
              .toString(),

      startsAt:
          _parseDateTime(
        json["starts_at"],
        json["starts_at_unix"],
      ),

      endsAt:
          _parseNullableDateTime(
        json["ends_at"],
        json["ends_at_unix"],
      ),

      posterUrl:
          _nullableString(
        json["poster_url"],
      ),

      ticketUrl:
          _nullableString(
        json["ticket_url"],
      ),

      tags:
          _parseStringList(
        json["tags"],
      ),

      hypeCount:
          _parseInt(
        json["hype_count"],
      ),

      goingCount:
          _parseInt(
        json["going_count"],
      ),

      createdAt:
          _parseDateTime(
        json["created_at"],
        json["created_at_unix"],
      ),

      publishedAt:
          _parseNullableDateTime(
        json["published_at"],
        json["published_at_unix"],
      ),
    );
  }

  static int _parseInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
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

  static DateTime _parseDateTime(
    dynamic isoValue,
    dynamic unixValue,
  ) {
    final unix =
        int.tryParse(
      unixValue?.toString() ?? "",
    );

    if (unix != null &&
        unix > 0) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        unix * 1000,
        isUtc: true,
      );
    }

    final parsed =
        DateTime.tryParse(
      isoValue?.toString() ?? "",
    );

    if (parsed != null) {
      return parsed.toUtc();
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
      isUtc: true,
    );
  }

  static DateTime?
      _parseNullableDateTime(
    dynamic isoValue,
    dynamic unixValue,
  ) {
    final unix =
        int.tryParse(
      unixValue?.toString() ?? "",
    );

    if (unix != null &&
        unix > 0) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        unix * 1000,
        isUtc: true,
      );
    }

    final raw =
        isoValue
                ?.toString()
                .trim() ??
            "";

    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      raw,
    )?.toUtc();
  }

  bool get isPublished =>
      status == "published";

  bool get hasPoster =>
      posterUrl != null;

  bool get hasTicketLink =>
      ticketUrl != null;
}