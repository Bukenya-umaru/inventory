import 'dart:async';

import 'api_service.dart';
import 'app_events.dart';
import 'notification_sound_service.dart';

/// Watches for new activity in the background and plays a notification
/// sound on the device when something new arrives (admin + employee only;
/// the activity endpoint itself rejects other roles).
class ActivityWatcher {
  ActivityWatcher._();
  static final ActivityWatcher instance = ActivityWatcher._();

  static const _interval = Duration(seconds: 20);
  Timer? _timer;
  int _lastSeenCount = -1; // unread count seen on the previous poll
  bool _checking = false;
  bool _started = false;
  String? _role;

  /// Called by the notification bell so the watcher knows the current role
  /// (only admin/employee accounts receive activity notifications).
  void updateRole(String? role) {
    _role = role;
  }

  void start() {
    if (_started) return;
    _started = true;
    _poll(); // initial sync without sound (establishes baseline)
    _timer = Timer.periodic(_interval, (_) => _poll());
    // Instant check whenever data changes anywhere in the app
    AppEvents.instance.subscribe(_onEvent);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void _onEvent(String event) {
    if (['sales', 'purchases', 'damages', 'products', 'categories']
        .contains(event)) {
      _poll();
    }
  }

  Future<void> _poll() async {
    if (_checking) return;
    if (_role != null && _role != 'admin' && _role != 'employee') return;
    _checking = true;
    try {
      final res = await ApiService.getActivity(limit: 1);
      final unread = (res['unreadCount'] ?? 0) as int;
      if (_lastSeenCount >= 0 && unread > _lastSeenCount) {
        // New activity arrived since the last check -> chime
        await NotificationSoundService.instance.play();
      }
      _lastSeenCount = unread;
    } catch (_) {
      // Offline or not a business account — stay silent
    } finally {
      _checking = false;
    }
  }

  /// Re-sync the baseline (e.g. after marking all as seen) without sound.
  Future<void> resync() async {
    _lastSeenCount = -1;
    await _poll();
  }
}
