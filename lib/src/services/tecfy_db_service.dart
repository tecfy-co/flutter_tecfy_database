part of '../../tecfy_database.dart';

/// The top-level handle for a Tecfy database. Construct it once with all your
/// [TecfyCollection]s, `await` [isReady], then read/write through
/// [collection]. Realtime `stream()`s update automatically on notifying writes.
class TecfyDatabase {
  /// Serializes single-document reads and writes.
  static final _TecfyMutex _docLock = _TecfyMutex();

  /// True while a document read/write holds (or is queued for) the lock.
  static bool get dbLock => _docLock.isLocked;
  static Database? _database;
  final Map<String, List<TecfyIndexField?>> _columns = {};
  bool _loading = true;
  List<TecfyListener> listeners = [];
  String? dbName;
  String databasesPath = "";
  Map<String, TecfyCollectionOperations>? operations;

  /// Returns the operations handle for the declared collection [name].
  /// Throws if the database isn't initialized or the collection wasn't declared.
  TecfyCollectionOperations collection(String name) {
    if (operations == null || operations![name] == null) {
      throw Exception(
          "Database not initialized or collection not found: $name");
    }
    return operations![name]!;
  }

  /// Creates the database and immediately begins opening it.
  ///
  /// [collections] declares every collection (table) up front.
  /// [dbName] overrides the on-disk file name (defaults to `tecfy_db.db`).
  /// [databaseFactory] overrides automatic platform detection — pass
  /// `databaseFactoryFfi` (with `sqfliteFfiInit()` called once) to run on the
  /// Dart VM / in tests / on desktop without platform channels.
  /// [inMemory] opens an ephemeral in-memory database (`inMemoryDatabasePath`)
  /// and skips `path_provider` resolution. Ideal for tests.
  TecfyDatabase({
    required List<TecfyCollection> collections,
    this.dbName,
    DatabaseFactory? databaseFactory,
    bool inMemory = false,
  }) {
    _initDb(
      collections: collections,
      overrideFactory: databaseFactory,
      inMemory: inMemory,
    );
  }

  void _initDb({
    required List<TecfyCollection> collections,
    DatabaseFactory? overrideFactory,
    bool inMemory = false,
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
      if (overrideFactory != null) {
        // Test/custom seam: a caller-provided factory (and optional in-memory
        // path) bypasses all platform detection and path_provider resolution.
        databaseFactory = overrideFactory;
        databasesPath = inMemory ? inMemoryDatabasePath : path;
        _database = await openDatabase(databasesPath, version: 3);
      } else {
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
            }
          } catch (e) {
            databasesPath = "";
          }
          String dbPath = join(databasesPath, path);
          debugPrint('------------------------------ db path $dbPath');
          _database = await openDatabase(dbPath, version: 3);
          debugPrint("Database Created, $dbPath");
        }
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

  /// Closes the database, unregisters the GetIt singleton and clears
  /// operations so a later re-init works. Returns once the file is closed.
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    if (GetIt.I.isRegistered<Database>(instanceName: 'tecfyDatabase')) {
      GetIt.I.unregister<Database>(instanceName: 'tecfyDatabase');
    }
    operations?.clear();
    _columns.clear();
  }

  /// Deletes all rows in every collection (keeps tables and schema).
  Future<void> clearDb() async {
    for (var key in (operations?.keys.toList() ?? [])) {
      await _database?.execute("DELETE FROM $key;");
    }
    _columns.clear();
  }

  /// Resolves to `true` once the database file is open and every collection's
  /// table and indexes exist. Always `await` this before the first read/write.
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
