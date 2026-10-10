import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';


class DraftStorageService {
  static final SharedPreferencesAsync
      _preferences =
          SharedPreferencesAsync();

  static const String
      _createEventDraftPrefix =
          'yiyo.create_event_draft.v1';

  static const String
      _vibeReportDraftPrefix =
          'yiyo.vibe_report_draft.v1';

  static const Duration
      _vibeReportDraftLifetime =
          Duration(
    minutes: 30,
  );


  static String? _userScopedKey(
    String prefix,
  ) {
    final uid =
        AuthService.currentUser
            ?.uid
            .trim();

    if (
        uid == null ||
        uid.isEmpty) {
      return null;
    }

    return '$prefix.$uid';
  }


  static String? _venueScopedKey(
    String prefix,
    String venueId,
  ) {
    final userKey =
        _userScopedKey(
      prefix,
    );

    final cleanVenueId =
        venueId.trim();

    if (
        userKey == null ||
        cleanVenueId.isEmpty) {
      return null;
    }

    return '$userKey.$cleanVenueId';
  }


  // ---------------------------------------------------------------------------
  // Create Event
  // ---------------------------------------------------------------------------

  static Future<void>
      saveCreateEventDraft(
    Map<String, dynamic> draft,
  ) async {
    final key =
        _userScopedKey(
      _createEventDraftPrefix,
    );

    if (key == null) {
      return;
    }

    await _preferences.setString(
      key,
      jsonEncode(
        draft,
      ),
    );
  }


  static Future<Map<String, dynamic>?>
      loadCreateEventDraft() async {
    final key =
        _userScopedKey(
      _createEventDraftPrefix,
    );

    if (key == null) {
      return null;
    }

    final raw =
        await _preferences.getString(
      key,
    );

    if (
        raw == null ||
        raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded =
          jsonDecode(
        raw,
      );

      if (decoded is! Map) {
        await _preferences.remove(
          key,
        );

        return null;
      }

      return Map<String, dynamic>.from(
        decoded,
      );
    } catch (_) {
      // If a stored draft ever becomes
      // unreadable, discard it rather
      // than breaking Create Event.
      await _preferences.remove(
        key,
      );

      return null;
    }
  }


  static Future<void>
      clearCreateEventDraft() async {
    final key =
        _userScopedKey(
      _createEventDraftPrefix,
    );

    if (key == null) {
      return;
    }

    await _preferences.remove(
      key,
    );
  }


  // ---------------------------------------------------------------------------
  // Vibe / Safety report
  // ---------------------------------------------------------------------------

  static Future<void>
      saveVibeReportDraft({
    required String venueId,
    required Map<String, dynamic> draft,
  }) async {
    final key =
        _venueScopedKey(
      _vibeReportDraftPrefix,
      venueId,
    );

    if (key == null) {
      return;
    }

    final payload = {
      ...draft,

      "saved_at_unix":
          DateTime.now()
                  .toUtc()
                  .millisecondsSinceEpoch ~/
              1000,
    };

    await _preferences.setString(
      key,
      jsonEncode(
        payload,
      ),
    );
  }


  static Future<Map<String, dynamic>?>
      loadVibeReportDraft({
    required String venueId,
  }) async {
    final key =
        _venueScopedKey(
      _vibeReportDraftPrefix,
      venueId,
    );

    if (key == null) {
      return null;
    }

    final raw =
        await _preferences.getString(
      key,
    );

    if (
        raw == null ||
        raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded =
          jsonDecode(
        raw,
      );

      if (decoded is! Map) {
        await _preferences.remove(
          key,
        );

        return null;
      }

      final draft =
          Map<String, dynamic>.from(
        decoded,
      );

      final savedAtUnix =
          (draft[
                    "saved_at_unix"
                  ] as num?)
              ?.toInt();

      if (savedAtUnix == null) {
        await _preferences.remove(
          key,
        );

        return null;
      }

      final savedAt =
          DateTime
              .fromMillisecondsSinceEpoch(
        savedAtUnix * 1000,
        isUtc: true,
      );

      final age =
          DateTime.now()
              .toUtc()
              .difference(
        savedAt,
      );

      if (
          age.isNegative ||
          age >
              _vibeReportDraftLifetime) {
        await _preferences.remove(
          key,
        );

        return null;
      }

      return draft;
    } catch (_) {
      // Vibe reports describe conditions
      // "right now". An unreadable or stale
      // draft should never be submitted later.
      await _preferences.remove(
        key,
      );

      return null;
    }
  }


  static Future<void>
      clearVibeReportDraft({
    required String venueId,
  }) async {
    final key =
        _venueScopedKey(
      _vibeReportDraftPrefix,
      venueId,
    );

    if (key == null) {
      return;
    }

    await _preferences.remove(
      key,
    );
  }
}