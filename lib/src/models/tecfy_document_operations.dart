part of '../../tecfy_database.dart';

/// Read/write/stream operations for a single document, addressed by primary
/// key via `db.collection(name).doc(id)`.
class TecfyDocumentOperations extends TecfyDocumentInterface {
  final TecfyCollectionOperations collection;
  final dynamic id;
  String? _primaryKeyFieldName;

  TecfyDocumentOperations(
    this.collection,
    this.id,
  ) {
    _primaryKeyFieldName =
        collection._primaryKeyFieldName(collection.collection.name);
  }

  @override
  Future<bool> delete({bool notifier = false, Batch? batch}) async {
    try {
      if (collection.database == null) return false;
      Map<String, dynamic>? doc;
      if (notifier) {
        doc = await get();
      }
      int result = 0;
      if (batch != null) {
        batch.delete(collection.collection.name,
            where: "$_primaryKeyFieldName = ?", whereArgs: [id]);
      } else {
        result = await TecfyDatabase._docLock.run(() => collection.database!
            .delete(collection.collection.name,
                where: "$_primaryKeyFieldName = ?", whereArgs: [id]));
      }
      if (result != 0) {
        if (notifier) {
          collection._sendListersUpdate(collection.collection.name, doc);
        }

        return true;
      } else {
        return false;
      }
    } catch (err) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> get() async {
    if (id == null || id.toString().isEmpty) return null;
    var result = await TecfyDatabase._docLock.run(() async =>
        collection.database?.query(collection.collection.name,
            where: "$_primaryKeyFieldName = ?", whereArgs: [id], limit: 1));

    if (result != null && result.isNotEmpty) {
      return jsonDecode(((result.first)['tecfy_json_body'] as String));
    } else {
      return null;
    }
  }

  @override
  Future<bool> update(
      {required Map<String, dynamic> data,
      Object? Function(Object? p1)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm,
      Batch? batch,
      bool notifier = false}) async {
    try {
      var body = collection._getInsertedBody(collection.collection.name, data);
      if (body == null || body.isEmpty) {
        throw Exception('Wrong Body');
      }
      if (id == null) {
        throw Exception('to update document provide primary key field on it');
      }
      var updateData = {
        ...body,
        "tecfy_json_body": jsonEncode(data,
            toEncodable: toEncodableEx ?? collection._customEncode)
      };
      int? result = 0;
      if (batch != null) {
        batch.update(
          collection.collection.name,
          updateData,
          where: "$_primaryKeyFieldName = ?",
          whereArgs: [id],
          conflictAlgorithm: conflictAlgorithm,
        );
      } else {
        result = await TecfyDatabase._docLock
            .run<int?>(() async => await collection.database?.update(
                  collection.collection.name,
                  updateData,
                  where: "$_primaryKeyFieldName = ?",
                  whereArgs: [id],
                  conflictAlgorithm: conflictAlgorithm,
                ));
      }
      if (result != 0) {
        if (notifier) {
          var doc = await get();
          collection._sendListersUpdate(collection.collection.name, doc);
          _sendListenerUpdateDoc(id);
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
    return collection._listenerStream<Map<String, dynamic>>(
        filter: filter, orderBy: orderBy, documentId: id);
  }

  void _sendListenerUpdateDoc(dynamic id) async {
    collection.listeners.removeWhere((l) => l.notifier.isClosed);

    collection.listeners
        .toList()
        .where((element) => element.documentId == id)
        .forEach((l) {
      l.sendUpdate();
    });
  }
}
