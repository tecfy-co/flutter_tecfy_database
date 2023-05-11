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
        doc = await getById();
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
  Future<Map<String, dynamic>?> getById() async {
    var result = await collection.database?.query(collection.collection.name,
        where: "$_primaryKeyFieldName = ?", whereArgs: [id], limit: 1);

    return (result?.first);
  }

  @override
  Future<bool> update(
      {required Map<String, dynamic> data,
      Object? Function(Object? p1)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm}) async {
    try {
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
        collection._sendListersUpdate(collection.collection.name, {});
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
