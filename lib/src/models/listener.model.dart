part of tecfy_database;

class TecfyListener {
  late TecfyCollectionOperations collection;
  late String collectionName;
  late StreamController notifier;
  ITecfyDbFilter? filter;
  String? orderBy;
  dynamic documentId;
  TecfyListener(this.collection, this.collectionName, this.notifier,
      {this.orderBy, this.filter, this.documentId});

  void sendUpdate() async {
    if (notifier is StreamController<int>) {
      sendUpdateCount();
      return;
    }
    if (documentId != null) {
      collection.doc(documentId).get().then((e) {
        if (e != null) {
          notifier.add(e);
        }
      });
    } else {
      collection.search(filter: filter, orderBy: orderBy).then((value) {
        notifier.add(value);
      });
    }
  }

  void sendUpdateCount() async {
    collection.searchCount(filter: filter).then((value) {
      notifier.add(value);
    });
  }
}
