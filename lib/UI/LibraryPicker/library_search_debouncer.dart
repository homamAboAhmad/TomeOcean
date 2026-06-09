import 'dart:async';

class LibrarySearchDebouncer {
  final Duration delay;
  Timer? _timer;

  LibrarySearchDebouncer({
    this.delay = const Duration(milliseconds: 180),
  });

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
