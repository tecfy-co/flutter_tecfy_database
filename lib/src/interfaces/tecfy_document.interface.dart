part of tecfy_database;

abstract class TecfyDocumentInterface {
  Future<bool> delete({bool notifier = false});
  Future<Map<String, dynamic>?> getById();
  Future<bool> update(
      {required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm});
}
