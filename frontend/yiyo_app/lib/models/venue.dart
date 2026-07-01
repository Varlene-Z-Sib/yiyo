class Venue {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double rating;
  final String address;
  final List<dynamic> types;
  final String? locationKey;
  final String? yiyoBadge;
  final double? distanceKm;
  final double? relevanceScore;

  Venue({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.address,
    required this.types,
    this.locationKey,
    this.yiyoBadge,
    this.distanceKm,
    this.relevanceScore,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: (json["place_id"] ?? json["id"] ?? json["name"]).toString(),
      name: (json["name"] ?? "Unknown Venue").toString(),
      lat: (json["lat"] as num).toDouble(),
      lng: (json["lng"] as num).toDouble(),
      rating: json["rating"] == null ? 0.0 : (json["rating"] as num).toDouble(),
      address: (json["address"] ?? "No address available").toString(),
      types: (json["types"] ?? []) as List<dynamic>,
      locationKey: json["location_key"]?.toString(),
      yiyoBadge: json["yiyo_badge"]?.toString(),
      distanceKm: json["distance_km"] == null
          ? null
          : (json["distance_km"] as num).toDouble(),
      relevanceScore: json["relevance_score"] == null
          ? null
          : (json["relevance_score"] as num).toDouble(),
    );
  }
}