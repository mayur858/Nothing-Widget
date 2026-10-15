import 'package:flutter/services.dart';

/// Thin wrapper around the native `mood_widget/usage` MethodChannel
/// (see MainActivity.kt). Every call degrades gracefully instead of throwing,
/// so a missing plugin (tests, non-Android platforms) or a platform error
/// can't surface as an unhandled async exception.
class UsageService {
  const UsageService();

  // Must match the channel name used in MainActivity.kt
  static const _channel = MethodChannel('mood_widget/usage');

  Future<bool> hasUsageAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on Exception {
      return false;
    }
  }

  /// Minutes the screen has been on since midnight, or `null` if it couldn't
  /// be read (callers should keep showing the previous value).
  Future<int?> screenOnMinutesToday() async {
    try {
      return await _channel.invokeMethod<int>('getScreenOnMinutesToday');
    } on Exception {
      return null;
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on Exception {
      return;
    }
  }
}
