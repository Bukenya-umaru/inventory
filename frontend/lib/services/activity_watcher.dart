import 'dart:async';

import 'api_service.dart';
import 'app_events.dart';
import 'notification_sound_service.dart';

class ActivityWatcher {
  ActivityWatcher._();
  static final ActivityWatcher instance = ActivityWatcher._();

  static const _interval = Duration(seconds: 20);
  Timer? _timer;
  int _lastSeenCount = -1; 
  bool _checking = false;
  bool _started = false;
  String? _role;

  void updateRole(String? role) {
    _role = role;
  }

  void start() {
    if (_started) return;
    _started = true;
    _poll(); 
    _timer = Timer.periodic(_interval, (_) => _poll());

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

        await NotificationSoundService.instance.play();
      }
      _lastSeenCount = unread;
    } catch (_) {

    } finally {
      _checking = false;
    }
  }

  Future<void> resync() async {
    _lastSeenCount = -1;
    await _poll();
  }
}