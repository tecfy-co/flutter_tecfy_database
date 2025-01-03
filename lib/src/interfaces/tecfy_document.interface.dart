part of tecfy_database;

abstract class TecfyDocumentInterface {
  Future<bool> delete({bool notifier = false});

  /// attach stream to document .
  Stream<Map<String, dynamic>> stream({
    ITecfyDbFilter? filter,
    String? orderBy,
  });
  Future<Map<String, dynamic>?> get();
  Future<bool> update(
      {required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm});
}
