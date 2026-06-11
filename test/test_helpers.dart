import 'package:tecfy_database/tecfy_database.dart';

/// Builds an in-memory database for tests. Call `sqfliteFfiInit()` once in
/// `main()` before using this.
TecfyDatabase newTestDb(List<TecfyCollection> collections) {
  return TecfyDatabase(
    collections: collections,
    inMemory: true,
    databaseFactory: databaseFactoryFfi,
  );
}

/// A 'tasks' collection with the common indexes used across tests.
TecfyCollection tasksCollection() => TecfyCollection('tasks', tecfyIndexFields: [
      [TecfyIndexField(name: 'title', type: FieldTypes.text, nullable: false)],
      [TecfyIndexField(name: 'priority', type: FieldTypes.integer)],
      [TecfyIndexField(name: 'isDone', type: FieldTypes.boolean)],
    ]);
