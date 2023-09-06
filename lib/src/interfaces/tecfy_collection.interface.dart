part of tecfy_database;

abstract class TecfyCollectionInterface {
  TecfyDocumentOperations doc([dynamic id]);

  /// attach stream to collection .
  Stream<List<Map<String, dynamic>>> stream({
    ITecfyDbFilter? filter,
    String? orderBy,
  });

  /// Fetch the documents for this collection
  Future<List<Map<String, dynamic>?>> get({String? orderBy, String? groupBy});

  /// delete collection
  Future<bool> delete();

  /// add new document
  Future<bool> add(
      {required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      String? nullColumnHack,
      ConflictAlgorithm? conflictAlgorithm});

  Future<List<Map<String, dynamic>>> search(
    String collectionName, {
    ITecfyDbFilter? filter,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
}
