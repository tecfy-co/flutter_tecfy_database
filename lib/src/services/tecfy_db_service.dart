part of '../../tecfy_database.dart';

class TecfyDatabase {
  static bool dbLock = false;
  static Database? _database;
  final Map<String, List<TecfyIndexField?>> _columns = {};
  bool _loading = true;
  List<TecfyListener> listeners = [];
  String? dbName;
  String databasesPath = "";
  Map<String, TecfyCollectionOperations>? operations;

  TecfyCollectionOperations collection(String name) {
    if(operations == null || operations![name] == null) {
      throw Exception("Database not initialized or collection not found: $name");
    }
    return operations![name]!;
  }

  TecfyDatabase({required List<TecfyCollection> collections, this.dbName}) {
    _initDb(collections: collections);
  }

  void _initDb({
    required List<TecfyCollection> collections,
  }) async {
    operations ??= {};
    if (_database != null) {
      // the database handle is static and already open (a previous instance
      // created it); recreate the collection operations so this instance is
      // usable instead of hanging in isReady() forever
      for (var coll in collections) {
        operations?[coll.name] = TecfyCollectionOperations(coll);
      }
      _loading = false;
      return;
    }
    String path = dbName ?? "tecfy_db.db";

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        // Initialize FFI
        sqfliteFfiInit();
        // Change the default factory
        databaseFactory = databaseFactoryFfi;
      }

      if (kIsWeb) {
        databasesPath = path;
        var factory = databaseFactoryFfiWeb;
        _database = await factory.openDatabase(databasesPath,
            options: OpenDatabaseOptions(
              version: 3,
            ));

        debugPrint("Database Created");
      } else {
        try {
          if (Platform.isWindows) {
            databasesPath =
                '${(await pathLib.getApplicationDocumentsDirectory()).path}\\';
          } else {
            databasesPath = await getDatabasesPath();
            // databasesPath = (await pathLib.getApplicationCacheDirectory()).path;
          }
        } catch (e) {
          databasesPath = "";
        }
        String dbPath = join(databasesPath, path);
        debugPrint('------------------------------ db path $dbPath');
        _database = await openDatabase(dbPath, version: 3);
        debugPrint("Database Created, $dbPath");
      }

      if (_database != null &&
          !GetIt.I.isRegistered<Database>(instanceName: 'tecfyDatabase')) {
        GetIt.I.registerSingleton<Database>(_database!,
            instanceName: 'tecfyDatabase');
      }
      for (var coll in collections) {
        operations?[coll.name] = TecfyCollectionOperations(coll);
      }
      // only flip after the operations exist, so isReady() can await them
      _loading = false;
    } catch (e) {
      _loading = false;
      debugPrint('$e');
      throw Exception(e.toString());
    }
  }

  void dispose() async {
    await _database?.close();
    _database = null;
    if (GetIt.I.isRegistered<Database>(instanceName: 'tecfyDatabase')) {
      GetIt.I.unregister<Database>(instanceName: 'tecfyDatabase');
    }
    operations?.clear();
    _columns.clear();
  }

  Future<void> clearDb() async {
    for (var key in (operations?.keys.toList() ?? [])) {
      await _database?.execute("DELETE FROM $key;");
    }
    _columns.clear();
  }

  Future<bool> isReady() async {
    while (_database == null || _loading) {
      await Future.delayed(Duration(milliseconds: 10));
    }
    // wait until every collection finished creating its table and indexes;
    // without this, queries issued right after isReady() could hit
    // "no such table" on a fresh install
    for (var operation
        in operations?.values.toList() ?? <TecfyCollectionOperations>[]) {
      try {
        await operation.ready;
      } catch (e) {
        debugPrint('collection ${operation.collection.name} init failed: $e');
      }
    }
    return true;
  }
}
