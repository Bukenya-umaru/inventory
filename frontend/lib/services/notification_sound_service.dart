import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';

/// Plays the notification chime when new activity arrives.
/// The user can mute/unmute; the preference persists locally and is exposed
/// through [mutedNotifier] so the UI can react instantly.
///
/// The [AudioPlayer] is created lazily on first [play] — never at startup.
/// On Flutter web the audioplayers handlers are NOT re-registered after a hot
/// restart, so eagerly constructing the player in `main()` throws
/// MissingPluginException on channel `xyz.luan/audioplayers.global` right
/// after every hot restart. With lazy creation, startup is always silent; if
/// the plugin is missing (web session after a hot restart), [play]
/// disables itself for the session and a full page reload restores sound.
class NotificationSoundService {
  NotificationSoundService._();
  static final NotificationSoundService instance = NotificationSoundService._();

  static const _muteKey = 'notification_sound_muted';
  AudioPlayer? _player;
  final ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(false);
  bool _loaded = false;
  bool _unavailable = false; // plugin not reachable (web after hot restart)

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
    // NOTE: no player warm-up here on purpose — creating the player at app
    // start crashes Flutter web sessions that were started via hot restart.
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

  /// Play the chime (no-op if muted or if the audio plugin is unavailable).
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
        // Plugin handlers are gone (Flutter web after hot restart).
        // Give up for this session; a full page reload restores sound.
        _unavailable = true;
        _player = null;
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  /// Preload the mute preference early (call at app start).
  Future<void> preload() => _ensureLoaded();
}
