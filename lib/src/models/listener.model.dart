part of tecfy_database;

class TecfyListener {
  late TecfyDatabase database;
  late String collectionName;
  late ITecfyDbFilter filter;
  late StreamController notifier;
  String? orderBy;
  TecfyListener(this.database, this.collectionName, this.filter, this.notifier,
      {this.orderBy});

  sendUpdate() {
    database.search(collectionName, filter, orderBy: orderBy).then((value) {
      notifier.add(value);
    });
  }
}
