/// Lightweight change-notification bus for cross-screen refreshes.
///
/// The main app keeps all screens alive in an [IndexedStack], so screens like
/// the Purchases section never re-run [State.initState] after the first build.
/// Any screen that changes shared data (restocks, purchases, sales, etc.)
/// notifies listeners so the affected sections can reload themselves.
class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  final List<void Function(String event)> _listeners = [];

  void subscribe(void Function(String event) listener) {
    _listeners.add(listener);
  }

  void unsubscribe(void Function(String event) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that something changed. [event] is a coarse tag:
  /// 'purchases', 'products', 'sales', 'damages', 'reports'.
  void emit(String event) {
    for (final l in List.of(_listeners)) {
      try {
        l(event);
      } catch (_) {
        // A broken listener must never break the emitter
      }
    }
  }
}
