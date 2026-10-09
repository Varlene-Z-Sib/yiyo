import 'yiyo_event.dart';


class EventApproval {
  final YiyoEvent event;

  final String organizerUsername;
  final String organizerFullName;
  final String organizerEmail;


  const EventApproval({
    required this.event,
    required this.organizerUsername,
    required this.organizerFullName,
    required this.organizerEmail,
  });


  factory EventApproval.fromJson(
    Map<String, dynamic> json,
  ) {
    return EventApproval(
      event:
          YiyoEvent.fromJson(
        json,
      ),

      organizerUsername:
          (json[
                    "organizer_username"
                  ] ??
                  "")
              .toString(),

      organizerFullName:
          (json[
                    "organizer_full_name"
                  ] ??
                  "")
              .toString(),

      organizerEmail:
          (json[
                    "organizer_email"
                  ] ??
                  "")
              .toString(),
    );
  }


  String get usernameLabel {
    final username =
        organizerUsername.trim();

    if (username.isEmpty) {
      return "No username";
    }

    return "@$username";
  }


  String get primaryIdentity {
    final fullName =
        organizerFullName.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final username =
        organizerUsername.trim();

    if (username.isNotEmpty) {
      return "@$username";
    }

    final email =
        organizerEmail.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return "Unknown organiser";
  }
}