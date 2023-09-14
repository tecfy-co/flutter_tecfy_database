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

  /// clear collection data
  Future<bool> clear();

  /// add new document
  Future<bool> add(
      {required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      String? nullColumnHack,
      ConflictAlgorithm? conflictAlgorithm});

  /// get number of elements
  Future<int> count({
    ITecfyDbFilter? filter,
  });

  /// check if element exists Or not (check only by document id)
  Future<bool> exists(dynamic id);

  /// search for values
  Future<List<Map<String, dynamic>>> search({
    ITecfyDbFilter? filter,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
}
