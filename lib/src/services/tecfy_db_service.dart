part of tecfy_database;

class TecfyDatabase {
  Database? _database;
  final Map<String, List<TecfyIndexField?>> _columns = {};
  final Map<String, List<TecfyIndexField>> _newcolumns = {};
  final Map<String, List<List<TecfyIndexField>>> _indexs = {};
  bool _loading = true;
  List<TecfyListener> listeners = [];
  String? dbName;
  Map<String, TecfyCollectionOperations>? operations;

  TecfyCollectionOperations collection(
    String name, {
    String? groupBy,
    String? orderBy,
  }) {
    return operations![name]!;
  }

  TecfyDatabase({required List<TecfyCollection> collections, this.dbName}) {
    _initDb(collections: collections);
  }

  void _initDb({
    required List<TecfyCollection> collections,
  }) async {
    String path = dbName ?? "tecfy_db.db";
    operations ??= {};

    try {
      if (kIsWeb) {
        var factory = databaseFactoryFfiWeb;
        _database = await factory.openDatabase(path,
            options: OpenDatabaseOptions(
              version: 3,
            ));

        print("Table Created");
      } else {
        String databasesPath = await getDatabasesPath();
        String dbPath = '${databasesPath}path';
        _database = await openDatabase(
          dbPath,
          version: 3,
        );
        print("Table Created");
      }

      if (_database != null) {
        GetIt.I.registerSingleton<Database>(_database!,
            instanceName: 'tecfyDatabase');
      }
      _loading = false;
      for (var collectin in collections) {
        operations?[collectin.name] = TecfyCollectionOperations(collectin);
      }
    } catch (e) {
      print(e);
      throw Exception(e.toString());
    }
  }

  void dispose() async {
    await _database?.close();
    _columns.clear();
  }

  // Future<void> clearCollection({required String collectionName}) async {
  //   try {
  //     await _database?.execute("DELETE FROM $collectionName");
  //   } catch (e) {
  //     throw Exception(e);
  //   }
  // }

  Future<bool> isReadey() async {
    while (_database == null || _loading)
      await Future.delayed(Duration(milliseconds: 10));
    return true;
  }
}
