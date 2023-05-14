part of tecfy_database;

class TecfyDocumentOperations extends TecfyDocumentInterface {
  final TecfyCollectionOperations collection;
  final dynamic id;
  String? _primaryKeyFieldName;

  TecfyDocumentOperations(
    this.collection,
    this.id,
  ) {
    print(collection.collection.name);
    _primaryKeyFieldName =
        collection._primaryKeyFieldName(collection.collection.name);
  }

  @override
  Future<bool> delete({bool notifier = false}) async {
    try {
      var doc;
      if (notifier) {
        doc = await get();
      }
      var result = await collection.database?.delete(collection.collection.name,
          where: "$_primaryKeyFieldName = ?", whereArgs: [id]);
      if (result != 0) {
        if (notifier) {
          collection._sendListersUpdate(collection.collection.name, doc);
        }

        return true;
      } else {
        return false;
      }
    } catch (err) {
      throw Exception(err);
    }
  }

  @override
  Future<Map<String, dynamic>?> get() async {
    var result = await collection.database?.query(collection.collection.name,
        where: "$_primaryKeyFieldName = ?", whereArgs: [id], limit: 1);

    return (result?.first);
  }

  @override
  Future<bool> update(
      {required Map<String, dynamic> data,
      Object? Function(Object? p1)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm,
      bool notifier = false}) async {
    var doc;

    try {
      if (notifier) {
        doc = await get();
      }

      var body = collection._getInsertedBody(collection.collection.name, data);
      if (body == null || body.isEmpty) {
        throw Exception('Wrong Body');
      }
      if (id == null) {
        throw Exception('to update document provide primary key field on it');
      }

      var result = await collection.database?.update(
        collection.collection.name,
        {
          ...body,
          "tecfy_json_body": jsonEncode(data,
              toEncodable: toEncodableEx ?? collection._customEncode)
        },
        where: "$_primaryKeyFieldName = ?",
        whereArgs: [id],
        conflictAlgorithm: conflictAlgorithm,
      );
      print('updated');
      if (result != 0) {
        if (notifier) {
          collection._sendListersUpdate(collection.collection.name, doc);
          _sendListnerUpdateDoc(id);
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Stream<Map<String, dynamic>> stream(
      {ITecfyDbFilter? filter, String? orderBy}) {
    var listner = StreamController<Map<String, dynamic>>.broadcast();
    var lis = TecfyListener(collection, collection.collection.name, listner,
        filter: filter, orderBy: orderBy, documentId: id);

    collection.listeners.add(lis);
    lis.sendUpdate();

    return listner.stream;
  }

  void _sendListnerUpdateDoc(id) async {
    var docListener = collection.listeners
        .firstWhereOrNull((element) => element.documentId == id);

    if (docListener?.notifier.isClosed ?? false) return;
    if (docListener?.notifier.isClosed ?? false) {
      throw Exception('No Listener for document');
    }
    docListener?.sendUpdate();
  }
}
