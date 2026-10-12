import 'package:flutter/services.dart';

/// Asks Android 13+ for the permission to show notifications,
/// and reports why a notification may not appear.
class NotificationPermission {
  static const MethodChannel _channel = MethodChannel('com.auramusic/files');

  /// True when notifications are allowed for this app.
  static Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Shows the system dialog "Allow Aura Music to send notifications?".
  static Future<bool> request() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the notification settings of this app.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
    } on PlatformException {
      // Nothing else to do.
    } on MissingPluginException {
      // Nothing else to do.
    }
  }

  /// Technical details used by the debug "Notification check" button.
  static Future<Map<String, dynamic>> info() async {
    try {
      final Map<String, dynamic>? result =
          await _channel.invokeMapMethod<String, dynamic>('notificationInfo');
      return result ?? <String, dynamic>{};
    } on PlatformException catch (e) {
      return <String, dynamic>{'error': e.message ?? e.code};
    } on MissingPluginException {
      return <String, dynamic>{'error': 'Kotlin code not installed (rebuild the app)'};
    }
  }
}