part of '../../tecfy_database.dart';

class TecfyListener {
  late TecfyCollectionOperations collection;
  late String collectionName;
  late StreamController notifier;
  ITecfyDbFilter? filter;
  String? orderBy;
  dynamic documentId;
  TecfyListener(this.collection, this.collectionName, this.notifier,
      {this.orderBy, this.filter, this.documentId});

  bool _running = false;
  bool _pending = false;

  /// Re-runs this listener's query and emits the result. Calls made while a
  /// query is already in flight are coalesced into one follow-up run, so a
  /// burst of writes costs at most two queries and results never arrive out
  /// of order.
  void sendUpdate() {
    if (notifier.isClosed) return;
    if (_running) {
      _pending = true;
      return;
    }
    _run();
  }

  /// Kept for backward compatibility; count listeners go through [sendUpdate].
  void sendUpdateCount() => sendUpdate();

  Future<void> _run() async {
    _running = true;
    try {
      do {
        _pending = false;
        try {
          final value = await _query();
          if (value != null && !notifier.isClosed) notifier.add(value);
        } catch (e, s) {
          if (!notifier.isClosed) notifier.addError(e, s);
        }
      } while (_pending && !notifier.isClosed);
    } finally {
      _running = false;
    }
  }

  Future<dynamic> _query() {
    if (notifier is StreamController<int>) {
      return collection.searchCount(filter: filter);
    }
    if (documentId != null) {
      return collection.doc(documentId).get();
    }
    return collection.search(filter: filter, orderBy: orderBy);
  }
}
