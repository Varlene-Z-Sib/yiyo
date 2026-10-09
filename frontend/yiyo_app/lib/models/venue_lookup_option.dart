class VenueLookupOption {
  final String id;

  final String name;

  final String address;


  const VenueLookupOption({
    required this.id,
    required this.name,
    required this.address,
  });


  factory VenueLookupOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return VenueLookupOption(
      id:
          (json["id"] ?? "")
              .toString()
              .trim(),

      name:
          (json["name"] ?? "")
              .toString()
              .trim(),

      address:
          (json["address"] ?? "")
              .toString()
              .trim(),
    );
  }
}