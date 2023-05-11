part of tecfy_database;

class TecfyListener {
  late TecfyCollectionOperations collection;
  late String collectionName;
  late StreamController notifier;
  ITecfyDbFilter? filter;
  String? orderBy;
  TecfyListener(
    this.collection,
    this.collectionName,
    this.notifier, {
    this.orderBy,
    this.filter,
  });

  sendUpdate() {
    collection
        .search(collectionName, filter: filter, orderBy: orderBy)
        .then((value) {
      notifier.add(value);
    });
  }
}
