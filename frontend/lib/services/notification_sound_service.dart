import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSoundService {
  NotificationSoundService._();
  static final NotificationSoundService instance = NotificationSoundService._();

  static const _muteKey = 'notification_sound_muted';
  AudioPlayer? _player;
  final ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(false);
  bool _loaded = false;
  bool _unavailable = false; 

  bool get isMuted => mutedNotifier.value;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      mutedNotifier.value = prefs.getBool(_muteKey) ?? false;
    } catch (_) {
      mutedNotifier.value = false;
    }
    _loaded = true;

  }

  AudioPlayer? _getOrCreatePlayer() {
    if (_unavailable) return null;
    try {
      return _player ??= AudioPlayer();
    } catch (e) {
      debugPrint('Notification sound unavailable: $e');
      _unavailable = true;
      return null;
    }
  }

  Future<void> setMuted(bool muted) async {
    mutedNotifier.value = muted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, muted);
    } catch (_) {}
  }

  Future<void> play() async {
    await _ensureLoaded();
    if (mutedNotifier.value) return;
    final player = _getOrCreatePlayer();
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      debugPrint('Notification sound failed: $e');
      if (e is MissingPluginException) {

        _unavailable = true;
        _player = null;
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> preload() => _ensureLoaded();
}