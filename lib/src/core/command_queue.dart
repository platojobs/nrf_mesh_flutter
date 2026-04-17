import 'dart:async';
import 'dart:collection';

typedef PlatoJobsMeshTaskRunner<T> = Future<T> Function();

class PlatoJobsMeshCommandQueue {
  PlatoJobsMeshCommandQueue({
    this.maxPending = 200,
    this.defaultTimeout = const Duration(seconds: 8),
  });

  final int maxPending;
  final Duration defaultTimeout;

  final Queue<PlatoJobsMeshQueuedTask<dynamic>> _queue =
      Queue<PlatoJobsMeshQueuedTask<dynamic>>();
  bool _draining = false;
  bool _disposed = false;

  int get pendingCount => _queue.length;

  Future<T> enqueue<T>(
    PlatoJobsMeshTaskRunner<T> runner, {
    Duration? timeout,
    String? debugLabel,
  }) {
    if (_disposed) {
      return Future<T>.error(StateError('CommandQueue is disposed'));
    }
    if (_queue.length >= maxPending) {
      return Future<T>.error(StateError('CommandQueue overflow (maxPending=$maxPending)'));
    }

    final completer = Completer<T>();
    _queue.add(
      PlatoJobsMeshQueuedTask<T>(
        runner: runner,
        completer: completer,
        timeout: timeout ?? defaultTimeout,
        debugLabel: debugLabel,
      ),
    );
    _drain();
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeFirst();
      task.completer.completeError(StateError('CommandQueue disposed'));
    }
  }

  void _drain() {
    if (_draining || _disposed) return;
    _draining = true;

    unawaited(() async {
      try {
        while (_queue.isNotEmpty && !_disposed) {
          final PlatoJobsMeshQueuedTask<dynamic> task = _queue.removeFirst();
          try {
            final result = await task.runner().timeout(task.timeout);
            task.completer.complete(result);
          } catch (e, st) {
            task.completer.completeError(e, st);
          }
        }
      } finally {
        _draining = false;
        if (_queue.isNotEmpty && !_disposed) {
          _drain();
        }
      }
    }());
  }
}

class PlatoJobsMeshQueuedTask<T> {
  PlatoJobsMeshQueuedTask({
    required this.runner,
    required this.completer,
    required this.timeout,
    required this.debugLabel,
  });

  final PlatoJobsMeshTaskRunner<T> runner;
  final Completer<T> completer;
  final Duration timeout;
  final String? debugLabel;
}

