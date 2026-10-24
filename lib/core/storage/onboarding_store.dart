// lib/core/storage/onboarding_store.dart
//
// "Onboarding completed" flag.
//
// Why not FlutterSecureStorage like the rest of the session data?
// logout() (auth_repository), profile logout, admin logout and SessionGuard
// (401) all call `_storage.deleteAll()`. A flag kept there would be erased on
// every logout / expired session, and onboarding would reappear on the next
// cold start. This flag is not session data, so it lives in a tiny marker file
// in the app-support directory (path_provider is already a dependency).
//
// Swapping to another backing store later is a change to this file only.
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OnboardingStore {
  OnboardingStore._();

  static const String _fileName = 'onboarding_completed';
  static bool _completedInMemory = false;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  /// Never throws. If the marker cannot be read we treat onboarding as not
  /// completed: showing it once more is the safe failure mode.
  static Future<bool> isCompleted() async {
    if (_completedInMemory) return true;
    try {
      final done = await (await _file()).exists();
      _completedInMemory = done;
      return done;
    } catch (_) {
      return false;
    }
  }

  /// Never throws. Safe to call more than once.
  static Future<void> markCompleted() async {
    _completedInMemory = true;
    try {
      final file = await _file();
      final dir = file.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await file.writeAsString('1', flush: true);
    } catch (_) {
      // Non-fatal: the in-memory flag still covers this session.
    }
  }
}
