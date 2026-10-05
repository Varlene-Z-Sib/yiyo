class EventEngagement {
  final String eventId;

  final int hypeCount;
  final int goingCount;

  final bool hypedByMe;
  final bool goingByMe;

  const EventEngagement({
    required this.eventId,
    required this.hypeCount,
    required this.goingCount,
    required this.hypedByMe,
    required this.goingByMe,
  });

  factory EventEngagement.fromJson(
    Map<String, dynamic> json,
  ) {
    return EventEngagement(
      eventId:
          (json["event_id"] ?? "")
              .toString(),

      hypeCount:
          _parseInt(
        json["hype_count"],
      ),

      goingCount:
          _parseInt(
        json["going_count"],
      ),

      hypedByMe:
          json["hyped_by_me"] ==
              true,

      goingByMe:
          json["going_by_me"] ==
              true,
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

  EventEngagement copyWith({
    int? hypeCount,
    int? goingCount,
    bool? hypedByMe,
    bool? goingByMe,
  }) {
    return EventEngagement(
      eventId:
          eventId,

      hypeCount:
          hypeCount ??
              this.hypeCount,

      goingCount:
          goingCount ??
              this.goingCount,

      hypedByMe:
          hypedByMe ??
              this.hypedByMe,

      goingByMe:
          goingByMe ??
              this.goingByMe,
    );
  }
}