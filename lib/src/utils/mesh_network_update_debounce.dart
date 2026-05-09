import 'dart:async';

/// Debounces **`meshNetworkUpdatedStream`**-style emissions so bursty native
/// **`NetworkUpdated`** signals collapse into one event after [quietPeriod]
/// of silence.
///
/// The **latest** sequence value received during the burst is forwarded.
/// Each call subscribes independently to [source] (fine for broadcast streams).
///
/// Phase **2.2** helper — keeps app-side refresh logic simple using **`dart:async`**
/// only (no extra runtime pub dependencies such as `rxdart`).
Stream<int> debounceMeshNetworkUpdates(
  Stream<int> source,
  Duration quietPeriod,
) {
  late StreamController<int> controller;
  StreamSubscription<int>? subscription;
  Timer? timer;
  int? pending;

  controller = StreamController<int>(
    sync: true,
    onListen: () {
      subscription = source.listen(
        (seq) {
          pending = seq;
          timer?.cancel();
          timer = Timer(quietPeriod, () {
            final value = pending;
            pending = null;
            if (value != null && !controller.isClosed) {
              controller.add(value);
            }
          });
        },
        onError: controller.addError,
        onDone: () async {
          timer?.cancel();
          await controller.close();
        },
        cancelOnError: false,
      );
    },
    onCancel: () async {
      timer?.cancel();
      await subscription?.cancel();
      subscription = null;
    },
  );

  return controller.stream;
}
