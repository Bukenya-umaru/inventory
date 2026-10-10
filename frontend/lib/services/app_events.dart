class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();
  static const globalSearchPrefix = 'global_search:';

  static String? globalSearchQuery(String event) {
    if (!event.startsWith(globalSearchPrefix)) return null;
    return event.substring(globalSearchPrefix.length);
  }

  final List<void Function(String event)> _listeners = [];

  void subscribe(void Function(String event) listener) {
    _listeners.add(listener);
  }

  void unsubscribe(void Function(String event) listener) {
    _listeners.remove(listener);
  }

  void emit(String event) {
    for (final l in List.of(_listeners)) {
      try {
        l(event);
      } catch (_) {}
    }
  }
}
