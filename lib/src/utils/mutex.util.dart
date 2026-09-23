part of '../../tecfy_database.dart';

/// A FIFO async lock. Waiters are woken as soon as the holder finishes
/// (no polling), and the lock is always released, even when the action throws.
class _TecfyMutex {
  Future<void> _tail = Future.value();
  int _pending = 0;

  /// True while an action holds the lock or is queued for it.
  bool get isLocked => _pending > 0;

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    _pending++;
    return previous.then((_) => action()).whenComplete(() {
      _pending--;
      done.complete();
    });
  }
}
