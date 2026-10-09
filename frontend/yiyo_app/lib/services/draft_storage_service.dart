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
}