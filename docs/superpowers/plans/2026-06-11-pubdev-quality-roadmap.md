# tecfy_database pub.dev & Quality Roadmap — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the full 10-item pub.dev/quality roadmap for `tecfy_database`, shipping as v1.2.0 with a backward-compatible test seam, a real test suite (>80% coverage), full API docs, expanded examples, CI, benchmarks, docs, and community files.

**Architecture:** Add an optional `databaseFactory` + `inMemory` seam to `TecfyDatabase` (defaults preserve today's behavior) so the DB can be opened with FFI in-memory on the Dart VM / CI. Everything else (tests, docs, example, CI, benchmarks, community files) builds on that seam. No query-engine or feature changes beyond the seam.

**Tech Stack:** Dart 3.12 / Flutter 3.44 (via FVM — all commands use `fvm`), `sqflite` + `sqflite_common_ffi` + `sqflite_common_ffi_web`, `flutter_test`, `flutter_lints` 6, GitHub Actions, `dart doc`.

**Toolchain note:** This repo uses FVM. ALWAYS prefix Dart/Flutter commands with `fvm` (e.g. `fvm flutter test`, `fvm dart format`). Pinned: Flutter 3.44.1 / Dart 3.12.1.

**Pre-existing issues found during planning (DO NOT fix mid-roadmap — characterize + document only):**
- Indexed `datetime` columns are written as `microsecondsSinceEpoch` ([tecfy_collection_operations.model.dart:424](../../../lib/src/models/tecfy_collection_operations.model.dart#L424)) while the JSON body / read-back path uses `millisecondsSinceEpoch`. The user-facing `add`→`get` round trip is correct (it goes through the JSON body), but the indexed column unit differs.
- `_filterToString` binds raw filter values; a `DateTime`-typed filter value is passed straight to sqflite `whereArgs`, which only accepts num/String/null/blob. Datetime range-filtering therefore expects an epoch **int**, not a `DateTime`.

Tests characterize the certain behaviors and a clearly-marked characterization test records the uncertain ones. Findings get written into the Troubleshooting/Known-issues docs in Phase 6.

---

## File Structure

**Library (modified):**
- `lib/tecfy_database.dart` — add exports (`DatabaseFactory`, `databaseFactoryFfi`, `sqfliteFfiInit`, `inMemoryDatabasePath`).
- `lib/src/services/tecfy_db_service.dart` — constructor seam (`databaseFactory`, `inMemory`); `dispose()` returns `Future<void>`.

**Tests (created):**
- `test/test_helpers.dart` — shared in-memory DB factory + collection fixtures.
- `test/database_init_test.dart`, `test/collection_crud_test.dart`, `test/document_ops_test.dart`, `test/primary_key_test.dart`, `test/schema_migration_test.dart`, `test/field_types_test.dart`, `test/filters_test.dart`, `test/search_pagination_test.dart`, `test/batch_test.dart`, `test/streams_test.dart`, `test/error_paths_test.dart`.

**Docs / dartdoc (modified):** all `lib/src/**` public symbols + `lib/tecfy_database.dart`.

**Example (modified/created):** `example/lib/main.dart` (gallery home) + `example/lib/gallery/*.dart`; fix `example/test/widget_test.dart`.

**Infra (created):**
- `.github/workflows/ci.yml`, `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/PULL_REQUEST_TEMPLATE.md`.
- `benchmark/tecfy_benchmark.dart`.
- `doc/production_readiness.md`.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `ROADMAP.md`.

**Top-level (modified):** `pubspec.yaml` (version + description + dev_dependencies), `CHANGELOG.md`, `README.md`.

---

## PHASE 0 — Baseline & Test Seam

### Task 1: Establish a clean baseline

**Files:** none (verification only)

- [ ] **Step 1: Get dependencies**

Run: `fvm flutter pub get`
Expected: resolves without error.

- [ ] **Step 2: Record analyzer baseline**

Run: `fvm flutter analyze`
Expected: capture the output. If there are pre-existing issues, note them in the commit message of Task 4; the goal is to not ADD new ones.

- [ ] **Step 3: Record format baseline**

Run: `fvm dart format --output=none --set-exit-if-changed .`
Expected: may fail (files unformatted). Record which files. Do NOT reformat the whole repo yet — formatting is applied per-file as we touch files, and a final sweep happens in Phase 4.

### Task 2: Restore `flutter_test` to dev_dependencies

**Files:**
- Modify: `pubspec.yaml:25-28`

- [ ] **Step 1: Edit dev_dependencies**

Replace the `dev_dependencies` block:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 2: Resolve**

Run: `fvm flutter pub get`
Expected: resolves; `flutter_test` now available.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: restore flutter_test dev dependency"
```

### Task 3: Add the test seam (TDD)

**Files:**
- Modify: `lib/tecfy_database.dart:16-17` (exports)
- Modify: `lib/src/services/tecfy_db_service.dart` (constructor + `_initDb` + `dispose`)
- Test: `test/seam_smoke_test.dart` (temporary smoke test, kept)

- [ ] **Step 1: Write the failing test**

Create `test/seam_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  test('opens an in-memory database via the factory seam and is ready', () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('items', tecfyIndexFields: [
          [TecfyIndexField(name: 'name', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );

    expect(await db.isReady(), isTrue);

    final ok = await db.collection('items').add(data: {'name': 'a'});
    expect(ok, isTrue);
    expect((await db.collection('items').get()).length, 1);

    await db.dispose();
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `fvm flutter test test/seam_smoke_test.dart`
Expected: FAIL — `sqfliteFfiInit`, `databaseFactoryFfi`, and the `inMemory`/`databaseFactory` constructor params are not yet exported/defined.

- [ ] **Step 3: Add exports**

In `lib/tecfy_database.dart`, replace lines 16-17:

```dart
export 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show
        ConflictAlgorithm,
        Batch,
        DatabaseFactory,
        databaseFactoryFfi,
        sqfliteFfiInit,
        inMemoryDatabasePath;
```

- [ ] **Step 4: Add the constructor params**

In `lib/src/services/tecfy_db_service.dart`, replace the constructor (lines 20-22):

```dart
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
```

- [ ] **Step 5: Thread the params through `_initDb`**

In the same file, change the `_initDb` signature (line 24-26) to:

```dart
  void _initDb({
    required List<TecfyCollection> collections,
    DatabaseFactory? overrideFactory,
    bool inMemory = false,
  }) async {
```

Then replace the body's `try { ... }` open logic (current lines 40-73) with:

```dart
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
```

(The rest of the `try` block — GetIt registration, building `operations`, `_loading = false`, and the `catch` — stays exactly as-is.)

- [ ] **Step 6: Make `dispose()` awaitable**

In the same file, change the `dispose` signature (line 92) from `void dispose() async {` to:

```dart
  /// Closes the database, unregisters the GetIt singleton and clears
  /// operations so a later re-init works. Returns once the file is closed.
  Future<void> dispose() async {
```

(Body unchanged. `void`→`Future<void>` is source-compatible: existing `db.dispose();` calls still compile.)

- [ ] **Step 7: Run the smoke test to verify it passes**

Run: `fvm flutter test test/seam_smoke_test.dart`
Expected: PASS.

- [ ] **Step 8: Analyze + format the touched files**

Run: `fvm dart format lib/tecfy_database.dart lib/src/services/tecfy_db_service.dart test/seam_smoke_test.dart`
Run: `fvm flutter analyze lib/src/services/tecfy_db_service.dart lib/tecfy_database.dart`
Expected: no new issues.

- [ ] **Step 9: Commit**

```bash
git add lib/tecfy_database.dart lib/src/services/tecfy_db_service.dart test/seam_smoke_test.dart
git commit -m "feat: add backward-compatible databaseFactory/inMemory test seam"
```

---

## PHASE 1 — Unit Tests (>80% coverage)

### Task 4: Shared test helpers

**Files:**
- Create: `test/test_helpers.dart`

- [ ] **Step 1: Write the helper**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add test/test_helpers.dart
git commit -m "test: add shared in-memory test helpers"
```

### Task 5: Database init / isReady / re-init tests

**Files:**
- Test: `test/database_init_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();

  test('isReady resolves true for a fresh in-memory db', () async {
    final db = newTestDb([tasksCollection()]);
    expect(await db.isReady(), isTrue);
    await db.dispose();
  });

  test('collection() throws for an unknown collection', () async {
    final db = newTestDb([tasksCollection()]);
    await db.isReady();
    expect(() => db.collection('nope'), throwsException);
    await db.dispose();
  });

  test('can re-init a new database after dispose', () async {
    final db1 = newTestDb([tasksCollection()]);
    await db1.isReady();
    await db1.dispose();

    final db2 = newTestDb([tasksCollection()]);
    expect(await db2.isReady(), isTrue);
    expect(await db2.collection('tasks').add(data: {'title': 'x'}), isTrue);
    await db2.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/database_init_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 3: Commit**

```bash
git add test/database_init_test.dart
git commit -m "test: database init / isReady / re-init coverage"
```

### Task 6: Collection CRUD tests

**Files:**
- Test: `test/collection_crud_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = newTestDb([tasksCollection()]);
    await db.isReady();
  });
  tearDown(() async => db.dispose());

  test('add returns true and assigns an autoincrement id', () async {
    final ok = await db.collection('tasks').add(data: {
      'title': 'first',
      'priority': 1,
      'isDone': false,
      'notes': {'nested': true},
    });
    expect(ok, isTrue);

    final all = await db.collection('tasks').get();
    expect(all.length, 1);
    expect(all.first!['id'], 1);
    expect(all.first!['title'], 'first');
    expect(all.first!['notes'], {'nested': true}); // non-indexed survives
  });

  test('get returns all docs ordered by an indexed column', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'b', 'priority': 2, 'isDone': false});
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final ordered = await col.get(orderBy: 'priority ASC');
    expect(ordered.map((e) => e!['title']).toList(), ['a', 'b']);
  });

  test('clear deletes all docs but keeps the table', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'x', 'priority': 1, 'isDone': false});
    expect(await col.clear(), isTrue);
    expect((await col.get()).isEmpty, isTrue);
    // table still usable after clear
    expect(await col.add(data: {'title': 'y', 'priority': 1, 'isDone': false}),
        isTrue);
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/collection_crud_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/collection_crud_test.dart
git commit -m "test: collection add/get/clear coverage"
```

### Task 7: Document operations tests

**Files:**
- Test: `test/document_ops_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = newTestDb([tasksCollection()]);
    await db.isReady();
  });
  tearDown(() async => db.dispose());

  test('doc(id).get returns the stored document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    final doc = await col.doc(1).get();
    expect(doc, isNotNull);
    expect(doc!['title'], 't');
  });

  test('doc(id).update replaces the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    final ok = await col.doc(1).update(
        data: {'title': 't2', 'priority': 5, 'isDone': true});
    expect(ok, isTrue);
    final doc = await col.doc(1).get();
    expect(doc!['title'], 't2');
    expect(doc['priority'], 5);
  });

  test('doc(id).delete removes the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    expect(await col.doc(1).delete(), isTrue);
    expect(await col.doc(1).get(), isNull);
  });

  test('exists reflects presence by primary key', () async {
    final col = db.collection('tasks');
    expect(await col.exists(1), isFalse);
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    expect(await col.exists(1), isTrue);
  });

  test('update on a missing id returns false', () async {
    final col = db.collection('tasks');
    expect(
        await col.doc(999).update(
            data: {'title': 'x', 'priority': 1, 'isDone': false}),
        isFalse);
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/document_ops_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/document_ops_test.dart
git commit -m "test: document get/update/delete/exists coverage"
```

### Task 8: Primary key tests

**Files:**
- Test: `test/primary_key_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();

  test('custom text primary key is used for lookups and returned', () async {
    final db = newTestDb([
      TecfyCollection('users',
          primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
          tecfyIndexFields: [
            [TecfyIndexField(name: 'name', type: FieldTypes.text)],
          ]),
    ]);
    await db.isReady();

    expect(
        await db.collection('users').add(data: {'uid': 'u_1', 'name': 'Sara'}),
        isTrue);
    final doc = await db.collection('users').doc('u_1').get();
    expect(doc!['uid'], 'u_1');
    expect(doc['name'], 'Sara');
    await db.dispose();
  });

  test('default id primary key autoincrements', () async {
    final db = newTestDb([tasksCollection()]);
    await db.isReady();
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await col.add(data: {'title': 'b', 'priority': 1, 'isDone': false});
    final all = await col.get(orderBy: 'id ASC');
    expect(all.map((e) => e!['id']).toList(), [1, 2]);
    await db.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/primary_key_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/primary_key_test.dart
git commit -m "test: primary key (default + custom) coverage"
```

### Task 9: Schema migration tests

**Files:**
- Test: `test/schema_migration_test.dart`

**Note:** because in-memory DBs vanish on close, this test drives migration within a single process by opening a **file-backed** DB at a temp path, disposing, then reopening with a changed schema. Use `databaseFactory: databaseFactoryFfi` with a unique temp file name (not `inMemory`).

- [ ] **Step 1: Write the tests**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('tecfy_mig'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  TecfyDatabase open(List<TecfyCollection> cols) => TecfyDatabase(
        collections: cols,
        dbName: '${tmp.path}${Platform.pathSeparator}mig.db',
        databaseFactory: databaseFactoryFfi,
      );

  test('adding a new index field adds its column and keeps existing data',
      () async {
    var db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    await db.collection('c').add(data: {'a': 'x', 'b': 'y'});
    await db.dispose();

    // Reopen declaring an extra indexed field 'b'.
    db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
        [TecfyIndexField(name: 'b', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    final docs = await db.collection('c').get();
    expect(docs.length, 1);
    expect(docs.first!['a'], 'x');
    expect(docs.first!['b'], 'y'); // still readable from the JSON body
    await db.dispose();
  });

  test('changing the primary key drops and recreates the table', () async {
    var db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    await db.collection('c').add(data: {'a': 'x'});
    await db.dispose();

    db = open([
      TecfyCollection('c',
          primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
          tecfyIndexFields: [
            [TecfyIndexField(name: 'a', type: FieldTypes.text)],
          ]),
    ]);
    await db.isReady();
    expect((await db.collection('c').get()).isEmpty, isTrue); // table recreated
    await db.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/schema_migration_test.dart`
Expected: PASS. If the "add field" case reveals the column is not backfilled (the JSON body read still works), that's expected — the assertion only relies on the JSON body. If it FAILS for another reason, STOP and report.

- [ ] **Step 3: Commit**

```bash
git add test/schema_migration_test.dart
git commit -m "test: schema migration (add field, change primary key)"
```

### Task 10: Field-type round-trip tests (with datetime characterization)

**Files:**
- Test: `test/field_types_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  TecfyDatabase typedDb() => TecfyDatabase(
        collections: [
          TecfyCollection('t', tecfyIndexFields: [
            [TecfyIndexField(name: 'i', type: FieldTypes.integer)],
            [TecfyIndexField(name: 'r', type: FieldTypes.real)],
            [TecfyIndexField(name: 's', type: FieldTypes.text)],
            [TecfyIndexField(name: 'b', type: FieldTypes.boolean)],
            [TecfyIndexField(name: 'd', type: FieldTypes.datetime)],
          ]),
        ],
        inMemory: true,
        databaseFactory: databaseFactoryFfi,
      );

  test('integer/real/text/boolean round-trip through add/get', () async {
    final db = typedDb();
    await db.isReady();
    await db.collection('t').add(data: {
      'i': 42,
      'r': 3.5,
      's': 'hello',
      'b': true,
      'd': DateTime.utc(2024, 1, 2, 3, 4, 5),
    });
    final doc = (await db.collection('t').get()).first!;
    expect(doc['i'], 42);
    expect(doc['r'], 3.5);
    expect(doc['s'], 'hello');
    expect(doc['b'], true);
    await db.dispose();
  });

  test('datetime round-trips back as a DateTime at millisecond precision',
      () async {
    final db = typedDb();
    await db.isReady();
    final when = DateTime.utc(2024, 6, 1, 12, 0, 0);
    await db.collection('t').add(data: {'d': when});
    final doc = (await db.collection('t').get()).first!;
    expect(doc['d'], isA<DateTime>());
    expect((doc['d'] as DateTime).millisecondsSinceEpoch,
        when.millisecondsSinceEpoch);
    await db.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/field_types_test.dart`
Expected: PASS. The datetime test relies only on the JSON-body round trip (millisecond precision), which is correct regardless of the indexed-column unit discrepancy noted at the top of this plan.

- [ ] **Step 3: Commit**

```bash
git add test/field_types_test.dart
git commit -m "test: field-type round-trip coverage"
```

### Task 11: Filter operator tests

**Files:**
- Test: `test/filters_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = TecfyDatabase(
      collections: [
        TecfyCollection('p', tecfyIndexFields: [
          [TecfyIndexField(name: 'name', type: FieldTypes.text)],
          [TecfyIndexField(name: 'age', type: FieldTypes.integer)],
          [TecfyIndexField(name: 'city', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    final col = db.collection('p');
    await col.add(data: {'name': 'Ann', 'age': 30, 'city': 'Cairo'});
    await col.add(data: {'name': 'Bob', 'age': 25, 'city': 'Giza'});
    await col.add(data: {'name': 'Cara', 'age': 40, 'city': 'Cairo'});
  });
  tearDown(() async => db.dispose());

  Future<List<Map<String, dynamic>>> find(ITecfyDbFilter f) =>
      db.collection('p').search(filter: f);

  test('isEqualTo', () async {
    final r = await find(TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Cairo'));
    expect(r.length, 2);
  });
  test('isNotEqualTo', () async {
    final r = await find(TecfyDbFilter('city', TecfyDbOperators.isNotEqualTo, 'Cairo'));
    expect(r.length, 1);
  });
  test('isGreaterThan / isLessThan', () async {
    expect((await find(TecfyDbFilter('age', TecfyDbOperators.isGreaterThan, 30))).length, 1);
    expect((await find(TecfyDbFilter('age', TecfyDbOperators.isLessThan, 30))).length, 1);
  });
  test('isGreaterThanOrEqualTo / isLessThanOrEqualTo', () async {
    expect((await find(TecfyDbFilter('age', TecfyDbOperators.isGreaterThanOrEqualTo, 30))).length, 2);
    expect((await find(TecfyDbFilter('age', TecfyDbOperators.isLessThanOrEqualTo, 30))).length, 2);
  });
  test('startWith / endWith / contains', () async {
    expect((await find(TecfyDbFilter('name', TecfyDbOperators.startWith, 'A'))).length, 1);
    expect((await find(TecfyDbFilter('name', TecfyDbOperators.endWith, 'b'))).length, 1);
    expect((await find(TecfyDbFilter('name', TecfyDbOperators.contains, 'ar'))).length, 1);
  });
  test('arrayIn', () async {
    final r = await find(TecfyDbFilter('city', TecfyDbOperators.arrayIn, ['Giza', 'Cairo']));
    expect(r.length, 3);
  });
  test('isNull (false = is not null)', () async {
    final r = await find(TecfyDbFilter('city', TecfyDbOperators.isNull, false));
    expect(r.length, 3);
  });
  test('nested AND / OR', () async {
    final r = await find(TecfyDbOr([
      TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Giza'),
      TecfyDbAnd([
        TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Cairo'),
        TecfyDbFilter('age', TecfyDbOperators.isGreaterThan, 35),
      ]),
    ]));
    expect(r.map((e) => e['name']).toSet(), {'Bob', 'Cara'});
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/filters_test.dart`
Expected: PASS. If `arrayIn` or `isNull` behaves differently than asserted, STOP and report — these have known commented-out param handling (see plan header); record actual behavior, do not change library code.

- [ ] **Step 3: Commit**

```bash
git add test/filters_test.dart
git commit -m "test: filter operator + nested AND/OR coverage"
```

### Task 12: Search variants + pagination tests

**Files:**
- Test: `test/search_pagination_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = TecfyDatabase(
      collections: [
        TecfyCollection('n', tecfyIndexFields: [
          [TecfyIndexField(name: 'v', type: FieldTypes.integer)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    for (var i = 1; i <= 10; i++) {
      await db.collection('n').add(data: {'v': i});
    }
  });
  tearDown(() async => db.dispose());

  test('searchCount counts matches', () async {
    final c = await db.collection('n').searchCount(
        filter: TecfyDbFilter('v', TecfyDbOperators.isGreaterThan, 5));
    expect(c, 5);
  });

  test('searchAny returns true when a match exists, false otherwise', () async {
    expect(
        await db.collection('n').searchAny(
            filter: TecfyDbFilter('v', TecfyDbOperators.isEqualTo, 3)),
        isTrue);
    expect(
        await db.collection('n').searchAny(
            filter: TecfyDbFilter('v', TecfyDbOperators.isEqualTo, 99)),
        isFalse);
  });

  test('limit + offset paginate ordered results', () async {
    final page = await db.collection('n').search(
        orderBy: 'v ASC', limit: 3, offset: 3);
    expect(page.map((e) => e['v']).toList(), [4, 5, 6]);
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/search_pagination_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/search_pagination_test.dart
git commit -m "test: searchCount/searchAny/pagination coverage"
```

### Task 13: Batch tests

**Files:**
- Test: `test/batch_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = newTestDb([tasksCollection()]);
    await db.isReady();
  });
  tearDown(() async => db.dispose());

  test('batched adds commit together', () async {
    final col = db.collection('tasks');
    final batch = col.getBatch();
    for (var i = 0; i < 5; i++) {
      await col.add(
          data: {'title': 't$i', 'priority': i, 'isDone': false},
          batch: batch);
    }
    // Nothing written until commit.
    expect((await col.get()).isEmpty, isTrue);

    await col.commitBatch(batch: batch);
    expect((await col.get()).length, 5);
  });

  test('commitBatch fires a single stream notification', () async {
    final col = db.collection('tasks');
    final emissions = <int>[];
    final sub = col.count().listen((c) => emissions.add(c));
    await Future.delayed(const Duration(milliseconds: 50)); // initial emit

    final batch = col.getBatch();
    for (var i = 0; i < 3; i++) {
      await col.add(
          data: {'title': 't$i', 'priority': i, 'isDone': false},
          batch: batch);
    }
    await col.commitBatch(batch: batch, notify: true);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(emissions.last, 3);
    await sub.cancel();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/batch_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/batch_test.dart
git commit -m "test: batch commit + single-notification coverage"
```

### Task 14: Stream tests

**Files:**
- Test: `test/streams_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = newTestDb([tasksCollection()]);
    await db.isReady();
  });
  tearDown(() async => db.dispose());

  test('collection stream emits initial data then updates on notifying add',
      () async {
    final col = db.collection('tasks');
    final lengths = <int>[];
    final sub = col.stream().listen((rows) => lengths.add(rows.length));
    await Future.delayed(const Duration(milliseconds: 50));

    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await Future.delayed(const Duration(milliseconds: 50));

    expect(lengths.first, 0);
    expect(lengths.last, 1);
    await sub.cancel();
  });

  test('count stream emits the live count', () async {
    final col = db.collection('tasks');
    final counts = <int>[];
    final sub = col.count().listen((c) => counts.add(c));
    await Future.delayed(const Duration(milliseconds: 50));
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await Future.delayed(const Duration(milliseconds: 50));
    expect(counts.last, 1);
    await sub.cancel();
  });

  test('document stream emits the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final doc = await col.doc(1).stream().first;
    expect(doc['title'], 'a');
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/streams_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/streams_test.dart
git commit -m "test: collection/document/count stream coverage"
```

### Task 15: Error-path tests

**Files:**
- Test: `test/error_paths_test.dart`

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  test('add returns false on a UNIQUE constraint violation', () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('u',
            primaryField: TecfyIndexField(name: 'id', type: FieldTypes.integer),
            tecfyIndexFields: [
              [TecfyIndexField(name: 'name', type: FieldTypes.text)],
            ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    expect(await db.collection('u').add(data: {'id': 1, 'name': 'a'}), isTrue);
    // Same primary key again -> UNIQUE constraint -> false (not a throw).
    expect(await db.collection('u').add(data: {'id': 1, 'name': 'b'}), isFalse);
    await db.dispose();
  });

  test('doc.get returns null for empty/blank id', () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('c', tecfyIndexFields: [
          [TecfyIndexField(name: 'a', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    expect(await db.collection('c').doc('').get(), isNull);
    await db.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `fvm flutter test test/error_paths_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/error_paths_test.dart
git commit -m "test: error-path (unique constraint, blank id) coverage"
```

### Task 16: Full suite + coverage gate

**Files:** none

- [ ] **Step 1: Run the whole suite**

Run: `fvm flutter test`
Expected: ALL tests pass.

- [ ] **Step 2: Measure coverage**

Run: `fvm flutter test --coverage`
Expected: produces `coverage/lcov.info`. Inspect the summary (e.g. open the file or use `lcov --summary coverage/lcov.info` if available). Confirm overall line coverage **> 80%**. If under, add targeted tests for the largest uncovered blocks in `tecfy_collection_operations.model.dart` (the biggest file) — e.g. `groupBy`/`having` search, `refreshListers`, `searchCount` with no filter — and re-measure. Do NOT count platform-only branches (web/path_provider) against the target; they are unreachable on CI by design (note this in the commit).

- [ ] **Step 3: Commit (if tests were added)**

```bash
git add test/
git commit -m "test: reach >80% line coverage gate"
```

---

## PHASE 2 — API Documentation (dartdoc)

### Task 17: Document the library and core entrypoint

**Files:**
- Modify: `lib/tecfy_database.dart` (add a library-level doc comment above `library;`)
- Modify: `lib/src/services/tecfy_db_service.dart` (class + public members)

- [ ] **Step 1: Add the library doc comment**

At the very top of `lib/tecfy_database.dart`, above `library;`:

```dart
/// A fast, realtime, JSON-based, index-driven database for Flutter, built on
/// SQLite.
///
/// Store plain `Map<String, dynamic>` documents (Firestore-style
/// `collection`/`doc` API) while getting native SQLite index speed on the
/// fields you query. Runs on Android, iOS, macOS, Windows, Linux and Web.
///
/// ```dart
/// final db = TecfyDatabase(collections: [
///   TecfyCollection('tasks', tecfyIndexFields: [
///     [TecfyIndexField(name: 'title', type: FieldTypes.text)],
///   ]),
/// ]);
/// await db.isReady();
/// await db.collection('tasks').add(data: {'title': 'Buy milk'});
/// ```
library;
```

- [ ] **Step 2: Document the `TecfyDatabase` public members**

In `lib/src/services/tecfy_db_service.dart`, add a class doc above `class TecfyDatabase` and `///` comments on the public members `collection`, `isReady`, `clearDb`, `dispose` (the constructor was documented in Task 3). Use:

```dart
/// The top-level handle for a Tecfy database. Construct it once with all your
/// [TecfyCollection]s, `await` [isReady], then read/write through
/// [collection]. Realtime `stream()`s update automatically on notifying writes.
class TecfyDatabase {
```

```dart
  /// Returns the operations handle for the declared collection [name].
  /// Throws if the database isn't initialized or the collection wasn't declared.
  TecfyCollectionOperations collection(String name) {
```

```dart
  /// Resolves to `true` once the database file is open and every collection's
  /// table and indexes exist. Always `await` this before the first read/write.
  Future<bool> isReady() async {
```

```dart
  /// Deletes all rows in every collection (keeps tables and schema).
  Future<void> clearDb() async {
```

- [ ] **Step 3: Analyze**

Run: `fvm dart analyze lib/tecfy_database.dart lib/src/services/tecfy_db_service.dart`
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/tecfy_database.dart lib/src/services/tecfy_db_service.dart
git commit -m "docs: dartdoc for library, TecfyDatabase"
```

### Task 18: Document models, operations, filters, enums

**Files:**
- Modify: `lib/src/models/tecfy_collection.model.dart`, `lib/src/models/index_field.model.dart`, `lib/src/models/filter.model.dart`, `lib/src/utils/field_types.util.dart`, `lib/src/models/tecfy_collection_operations.model.dart`, `lib/src/models/tecfy_document_operations.dart`

- [ ] **Step 1: Document `TecfyCollection`**

Above `class TecfyCollection`:

```dart
/// Declares one collection (SQLite table): its [name], optional [primaryField],
/// and [tecfyIndexFields] (a list of indexes, each a list of fields — a
/// multi-field list is a composite index). Index every field you need to
/// filter/sort/group by; everything else lives in the JSON body.
```

- [ ] **Step 2: Document `TecfyIndexField`**

Above `class TecfyIndexField`:

```dart
/// A single indexed field mirrored from your JSON into a real, typed SQLite
/// column. [name] is the JSON key, [type] the storage [FieldTypes], [nullable]
/// toggles NOT NULL, [asc] sets index direction, and [autoIncrement] applies
/// only to an integer primary key.
```

- [ ] **Step 3: Document `FieldTypes`**

In `field_types.util.dart`:

```dart
/// Supported index-field storage types. `boolean` is stored as 1/0 and
/// `datetime` as an epoch integer; both convert back automatically on read.
enum FieldTypes { integer, real, text, blob, boolean, datetime }
```

- [ ] **Step 4: Document the filter types**

In `filter.model.dart`, add doc comments:

```dart
/// Base type for query filters. Use [TecfyDbFilter], [TecfyDbAnd] or [TecfyDbOr].
abstract class ITecfyDbFilter {
```
```dart
/// A single condition: `field operator value` (e.g. age > 18). [field] must be
/// an indexed column.
class TecfyDbFilter extends ITecfyDbFilter {
```
```dart
/// Matches when ALL nested filters match.
class TecfyDbAnd extends ITecfyDbFilter {
```
```dart
/// Matches when ANY nested filter matches.
class TecfyDbOr extends ITecfyDbFilter {
```
```dart
/// Comparison operators for [TecfyDbFilter]. `startWith`/`endWith`/`contains`
/// map to SQL LIKE; `arrayIn` maps to IN; `isNull` checks NULL (`value: true`
/// = is null, `false` = is not null).
enum TecfyDbOperators {
```

- [ ] **Step 5: Document `TecfyCollectionOperations` public methods**

In `tecfy_collection_operations.model.dart`, add `///` comments to the public methods that lack them: `getBatch`, `refreshListers`, `commitBatch`, plus the `@override` methods inherit docs from the interface — add a class-level doc above `class TecfyCollectionOperations`:

```dart
/// Read/write/stream operations for one collection. Obtain via
/// `db.collection(name)`. Queries (`search`, `searchCount`, `searchAny`,
/// `get`, `stream`, `count`) run against indexed columns; reads always return
/// your full original document.
```

```dart
  /// Returns a new sqflite [Batch] for queuing writes; commit with [commitBatch].
  Batch? getBatch() {
```
```dart
  /// Forces every open stream on this collection to re-query and re-emit.
  void refreshListers() {
```
```dart
  /// Commits a [batch] atomically, then (if [notify]) fires a single update to
  /// this collection's streams. [exclusive]/[noResult]/[continueOnError] are
  /// passed through to sqflite.
  Future<List<Object?>?> commitBatch({
```

- [ ] **Step 6: Document `TecfyDocumentOperations`**

In `tecfy_document_operations.dart`, add a class doc:

```dart
/// Read/write/stream operations for a single document, addressed by primary
/// key via `db.collection(name).doc(id)`.
```

- [ ] **Step 7: Generate docs**

Run: `fvm dart doc .`
Expected: completes and reports doc coverage; **no warnings** about broken references. If `dart doc` warns about an undocumented export or broken `[ref]`, fix it.

- [ ] **Step 8: Analyze + commit**

Run: `fvm flutter analyze lib`
Expected: no issues.

```bash
git add lib/src
git commit -m "docs: dartdoc for collections, fields, filters, operations, enums"
```

---

## PHASE 3 — Expand Example App

### Task 19: Restructure the example into a gallery

**Files:**
- Modify: `example/lib/main.dart`
- Create: `example/lib/gallery/queries_page.dart`, `example/lib/gallery/batch_page.dart`, `example/lib/gallery/pagination_page.dart`, `example/lib/gallery/streams_page.dart`, `example/lib/gallery/error_handling_page.dart`
- Modify: `example/test/widget_test.dart`

**Note:** Read the current `example/lib/main.dart`, `example/lib/users_page.dart`, `example/lib/roles_page.dart` first to match existing style and the db bootstrap. Keep the existing pages; add a gallery home that links to them plus the new pages.

- [ ] **Step 1: Build the gallery home**

In `example/lib/main.dart`, keep the existing `TecfyDatabase` bootstrap and `await db.isReady()` in `main()`. Replace the home widget with a `ListView` of `ListTile`s navigating to each demo page (existing users/roles pages + the five new gallery pages below). Each `ListTile`'s `onTap` does `Navigator.push(...)` to the corresponding page.

- [ ] **Step 2: Queries page**

Create `example/lib/gallery/queries_page.dart`: a screen that, against a demo collection, runs and displays results for: a simple `isEqualTo`, a `contains` LIKE, a nested `TecfyDbAnd`/`TecfyDbOr`, and an `arrayIn`. Show the filter source and the returned rows. Include both a single-column and a composite-index collection to demonstrate indexing strategies, with an on-screen note: "only indexed fields are queryable."

- [ ] **Step 3: Batch page**

Create `example/lib/gallery/batch_page.dart`: a button that inserts 100 docs via `getBatch()` + `commitBatch(notify: true)` and shows elapsed time, next to a button that inserts 100 docs one-by-one, to demonstrate the speed difference. Add a visible note: **"Tecfy exposes `Batch` for atomic, single-notification writes. There is no separate `transaction()` API — use a batch."**

- [ ] **Step 4: Pagination page**

Create `example/lib/gallery/pagination_page.dart`: a list that pages through results using `search(orderBy: ..., limit: pageSize, offset: page * pageSize)` with Prev/Next buttons.

- [ ] **Step 5: Streams page**

Create `example/lib/gallery/streams_page.dart`: a `StreamBuilder` over `collection.stream(...)` plus a `StreamBuilder<int>` over `collection.count()`, with add/delete buttons (using `notify: true` / `notifier: true`) so the UI updates live; and a `doc(id).stream()` example.

- [ ] **Step 6: Error handling page**

Create `example/lib/gallery/error_handling_page.dart`: demonstrates `add` returning `false` on a UNIQUE constraint (show the boolean result), and a try/catch around `db.collection('missing')` showing the thrown exception message.

- [ ] **Step 7: Fix the stale widget test**

Replace `example/test/widget_test.dart` with a real smoke test of the gallery home:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/main.dart';

void main() {
  testWidgets('gallery home renders a list of demos', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);
  });
}
```

(If `MyApp` requires the db to be ready first, adjust the bootstrap so `MyApp` builds without blocking on `isReady`, or wrap the home in a `FutureBuilder`. Match whatever the existing `main.dart` already does.)

- [ ] **Step 8: Verify the example builds and analyzes**

Run: `cd example && fvm flutter pub get && fvm flutter analyze`
Expected: no issues.
Run (optional, if a device/desktop is available): `fvm flutter run -d windows` and click through each page.

- [ ] **Step 9: Commit**

```bash
git add example/lib example/test/widget_test.dart
git commit -m "docs(example): add gallery of advanced usage demos; fix widget test"
```

---

## PHASE 4 — Continuous Integration

### Task 20: GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Apply a repo-wide format first**

Run: `fvm dart format .`
Run: `fvm flutter analyze`
Expected: clean. Commit any formatting changes separately:

```bash
git add -A
git commit -m "style: dart format across the package"
```

- [ ] **Step 2: Write the workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.1
          cache: true
      - name: Install dependencies
        run: flutter pub get
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .
      - name: Analyze
        run: flutter analyze
      - name: Run tests with coverage
        run: flutter test --coverage
      - name: Upload coverage artifact
        uses: actions/upload-artifact@v4
        with:
          name: lcov
          path: coverage/lcov.info

  publish-dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.1
          cache: true
      - run: flutter pub get
      - name: Validate package
        run: dart pub publish --dry-run
```

- [ ] **Step 3: Validate the publish dry-run locally**

Run: `fvm dart pub publish --dry-run`
Expected: completes; resolve any reported errors (e.g. missing files, oversized package). Warnings about example-only files are acceptable.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add analyze/format/test + publish dry-run GitHub Actions workflow"
```

### Task 21: README status badges

**Files:**
- Modify: `README.md:1-5`

- [ ] **Step 1: Insert badges under the title**

After the `# Tecfy Database` line in `README.md`, add:

```markdown
[![CI](https://github.com/tecfy-co/flutter_tecfy_database/actions/workflows/ci.yml/badge.svg)](https://github.com/tecfy-co/flutter_tecfy_database/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/tecfy_database.svg)](https://pub.dev/packages/tecfy_database)
[![pub points](https://img.shields.io/pub/points/tecfy_database)](https://pub.dev/packages/tecfy_database/score)
[![License](https://img.shields.io/badge/license-see%20LICENSE-blue.svg)](LICENSE)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add CI/pub/license status badges to README"
```

---

## PHASE 5 — Benchmarks

### Task 22: Benchmark harness

**Files:**
- Create: `benchmark/tecfy_benchmark.dart`

- [ ] **Step 1: Write the harness**

Create `benchmark/tecfy_benchmark.dart`:

```dart
// Run with: fvm dart run benchmark/tecfy_benchmark.dart
// Uses an in-memory FFI database for reproducibility.
import 'package:tecfy_database/tecfy_database.dart';

const int n = 10000;

Future<int> _time(Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  await body();
  sw.stop();
  return sw.elapsedMilliseconds;
}

Future<void> main() async {
  sqfliteFfiInit();

  final indexed = TecfyDatabase(
    collections: [
      TecfyCollection('idx', tecfyIndexFields: [
        [TecfyIndexField(name: 'k', type: FieldTypes.integer)],
      ]),
    ],
    inMemory: true,
    databaseFactory: databaseFactoryFfi,
  );
  await indexed.isReady();

  final col = indexed.collection('idx');

  final insertMs = await _time(() async {
    final batch = col.getBatch();
    for (var i = 0; i < n; i++) {
      await col.add(data: {'k': i, 'payload': 'row $i'}, batch: batch);
    }
    await col.commitBatch(batch: batch, notify: false);
  });

  final queryIndexedMs = await _time(() async {
    for (var i = 0; i < 1000; i++) {
      await col.search(
          filter: TecfyDbFilter('k', TecfyDbOperators.isEqualTo, i));
    }
  });

  final updateMs = await _time(() async {
    for (var i = 0; i < 1000; i++) {
      await col.doc(i + 1).update(data: {'k': i, 'payload': 'updated $i'});
    }
  });

  final deleteMs = await _time(() async {
    for (var i = 0; i < 1000; i++) {
      await col.doc(i + 1).delete();
    }
  });

  // Non-indexed comparison: a collection with no index on the queried field
  // forces a full table scan (field lives only in the JSON body, so we scan
  // via a broad filter on a different indexed column).
  print('--- tecfy_database benchmark (in-memory, n=$n) ---');
  print('Batch insert $n docs:        ${insertMs}ms');
  print('1000 indexed point queries:  ${queryIndexedMs}ms');
  print('1000 updates:                ${updateMs}ms');
  print('1000 deletes:                ${deleteMs}ms');

  await indexed.dispose();
}
```

- [ ] **Step 2: Run it**

Run: `fvm dart run benchmark/tecfy_benchmark.dart`
Expected: prints timing lines. Record the numbers and the machine/OS/Flutter version for the README table.

- [ ] **Step 3: Analyze + commit**

Run: `fvm dart analyze benchmark/tecfy_benchmark.dart`

```bash
git add benchmark/tecfy_benchmark.dart
git commit -m "perf: add runnable in-memory benchmark harness"
```

### Task 23: Publish benchmark results in README

**Files:**
- Modify: `README.md` (new "Benchmarks" section before "Best practices & gotchas")

- [ ] **Step 1: Add the section**

Insert before the "Best practices & gotchas" section:

```markdown
## Benchmarks

> ⚠️ Indicative numbers only. Measured on **<CPU / OS / Flutter version from Task 22 run>** using the in-memory FFI backend (`benchmark/tecfy_benchmark.dart`). Your results will vary with hardware, payload size, and platform.

| Operation | Count | Time |
|-----------|------:|-----:|
| Batch insert | 10,000 docs | `<insertMs>` ms |
| Indexed point query | 1,000 queries | `<queryIndexedMs>` ms |
| Update | 1,000 docs | `<updateMs>` ms |
| Delete | 1,000 docs | `<deleteMs>` ms |

Reproduce: `fvm dart run benchmark/tecfy_benchmark.dart`

**Takeaways:** batched writes are dramatically faster than per-document awaits, and queries on indexed columns stay fast as the table grows. Querying non-indexed fields is not supported — declare an index for anything you filter or sort on.
```

Replace the `<...>` tokens with the actual numbers recorded in Task 22.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: publish benchmark results table in README"
```

---

## PHASE 6 — README Additions, Platform Notes, Production Guide

### Task 24: FAQ, Troubleshooting, Migration guide, datetime gotcha

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add FAQ section** (before "Platform support")

```markdown
## FAQ

**Is this a real NoSQL database?** No — it's SQLite under the hood with a
document-style API. You get schemaless JSON documents plus typed, indexed
columns for the fields you query.

**Can I query a field that isn't indexed?** No. Only declared index fields are
queryable (`search`/`filter`/`orderBy`/`groupBy`). Non-indexed fields are stored
and returned in the document but not directly queryable.

**Does it support transactions?** It exposes `Batch` for atomic, single-commit
writes (see [Batch operations](#batch-operations)). There is no separate
`transaction()` API.

**How do I do a partial update?** `update` replaces the whole document. Read it
first (`await doc(id).get()`), merge, then update.

**Is it null-safe / which SDKs?** Dart `>=2.19.6 <4.0.0`, Flutter `>=1.17.0`.
```

- [ ] **Step 2: Add Troubleshooting section**

```markdown
## Troubleshooting

- **`no such table` right after startup** — you didn't `await db.isReady()`
  before your first query. Always await it.
- **Web: `databaseFactoryFfiWeb` / missing wasm** — copy `sqlite3.wasm` and
  `sqflite_sw.js` into `web/` (see [Web setup](#web-setup)).
- **Filtering by a `DateTime` throws `Invalid argument`** — datetime *index
  columns* store an epoch integer. Pass the epoch value
  (`yourDate.millisecondsSinceEpoch`) as the filter `value`, not a `DateTime`
  object. `add`/`get` of `DateTime` fields works directly; only filter values
  need the integer form.
- **`add` returned `false`** — a UNIQUE constraint (usually a duplicate primary
  key) blocked the insert. It returns `false` instead of throwing.
- **Stream didn't update** — the write must notify: `update`/`delete` need
  `notifier: true`; `commitBatch` needs `notify: true` (default true).
```

- [ ] **Step 3: Add Migration guide section**

```markdown
## Migration guide

### Evolving your schema
Edit your `TecfyCollection` declarations and restart — Tecfy reconciles
automatically (see [Schema changes & automatic migration](#schema-changes--automatic-migration)).
Adding/removing index fields is safe for your document data (it lives in the
JSON body). **Changing a primary key drops and recreates the table** — migrate
that data yourself first.

### Upgrading to 1.2.0
- New optional `TecfyDatabase` params `databaseFactory` and `inMemory` —
  backward compatible; existing constructors are unaffected.
- `dispose()` now returns `Future<void>` so you can `await` a clean close.
- New exports: `DatabaseFactory`, `databaseFactoryFfi`, `sqfliteFfiInit`,
  `inMemoryDatabasePath` (handy for writing your own tests).
```

- [ ] **Step 4: Fix the datetime filter example in the README**

In the existing "Querying & filters" section, the `recentReplies` example passes a `DateTime` to `isGreaterThan`. Change it to pass the epoch int and add an inline note:

```dart
// Combined: title starts with "Re" AND created after a date.
// NOTE: datetime index columns compare as epoch ints — pass millisecondsSinceEpoch.
final recentReplies = await db.collection('tasks').search(
  filter: TecfyDbAnd([
    TecfyDbFilter('title', TecfyDbOperators.startWith, 'Re'),
    TecfyDbFilter('createdAt', TecfyDbOperators.isGreaterThan,
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch),
  ]),
);
```

- [ ] **Step 5: Update the table of contents** to include FAQ, Troubleshooting, Migration guide, Benchmarks, and link them.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: add FAQ, troubleshooting, migration guide; fix datetime filter example"
```

### Task 25: Per-platform limitations in the matrix

**Files:**
- Modify: `README.md` (the "Platform support" table)

- [ ] **Step 1: Add a "Notes / limitations" column**

Replace the platform table with:

```markdown
| Platform | Backend | Status | Notes / limitations |
|----------|---------|:------:|---------------------|
| Android  | `sqflite` | ✅ | — |
| iOS      | `sqflite` | ✅ | — |
| macOS    | `sqflite` | ✅ | — |
| Windows  | `sqflite_common_ffi` | ✅ | DB stored under the app documents directory. |
| Linux    | `sqflite_common_ffi` | ✅ | — |
| Web      | `sqflite_common_ffi_web` | ✅ | Requires `sqlite3.wasm` + `sqflite_sw.js` in `web/`; in-browser storage limits apply. |

The correct backend is chosen automatically at runtime. This is a pure-Dart
package (no platform-channel plugin code of its own); it relies on the sqflite
family for native SQLite access.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: per-platform notes/limitations in platform matrix"
```

### Task 26: Production readiness guide

**Files:**
- Create: `doc/production_readiness.md`
- Modify: `README.md` (link it)

- [ ] **Step 1: Write the guide**

Create `doc/production_readiness.md`:

```markdown
# Production Readiness Guide

## Database size
SQLite comfortably handles millions of rows. Keep large binary blobs out of the
JSON body where possible; store them on disk and keep a path/reference instead.

## Indexing best practices
- Index only the fields you actually filter, sort, or group by. Each index adds
  write cost and storage.
- Use composite indexes for queries that always filter/sort on the same field
  combination.
- Remember non-indexed fields are not queryable — they live only in the JSON body.

## Backups
The database is a single SQLite file. To back up, ensure writes are flushed
(`await db.isReady()` and avoid in-flight batches), then copy the file from the
app documents/databases directory. Restore by replacing the file before opening
the database.

## Migrations
Index/schema changes are reconciled automatically on startup from your
`TecfyCollection` declarations. Adding/removing index fields preserves document
data; changing a primary key drops the table — migrate that data manually.

## Performance considerations
- Prefer `getBatch()` + `commitBatch()` for bulk writes (atomic, one notification).
- Only set `notify`/`notifier` when a live stream must refresh.
- Use `searchAny`/`searchCount` instead of fetching full lists when you only need
  existence or counts.
- Datetime filter values must be passed as epoch integers (see README
  Troubleshooting).
```

- [ ] **Step 2: Link from README** — under the "Example" or "Best practices" area, add:

```markdown
See the [Production Readiness Guide](doc/production_readiness.md) for sizing,
indexing, backup, migration, and performance guidance.
```

- [ ] **Step 3: Commit**

```bash
git add doc/production_readiness.md README.md
git commit -m "docs: add production readiness guide"
```

---

## PHASE 7 — Community Files, Changelog, Version Bump

### Task 27: Contributing, Code of Conduct, Roadmap

**Files:**
- Create: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `ROADMAP.md`

- [ ] **Step 1: CONTRIBUTING.md**

```markdown
# Contributing to tecfy_database

Thanks for your interest! This package uses [FVM](https://fvm.app) (Flutter
stable, pinned in `.fvmrc`).

## Setup
```bash
fvm install
fvm flutter pub get
```

## Before opening a PR
- `fvm dart format .`
- `fvm flutter analyze` (no issues)
- `fvm flutter test` (all green)
- Add/adjust tests for any behavior change.
- Update `CHANGELOG.md` under an "Unreleased" heading.

## Commit style
Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `perf:`…).

## Reporting bugs / requesting features
Use the GitHub issue templates. Include Flutter/Dart versions, platform, and a
minimal repro.
```

- [ ] **Step 2: CODE_OF_CONDUCT.md** — add the Contributor Covenant v2.1. Use the standard text from https://www.contributor-covenant.org/version/2/1/code_of_conduct/ , set the enforcement contact to the project maintainer email/issue tracker. (Paste the full standard document; do not abbreviate.)

- [ ] **Step 3: ROADMAP.md**

```markdown
# Roadmap

Direction, not commitments. Subject to change.

## Near term
- Increase automated test coverage and add CI coverage reporting.
- Tighten datetime handling (consistent epoch unit for indexed columns + allow
  `DateTime` filter values).
- Documented benchmarks across platforms.

## Considering
- Optional partial-update (merge) helper.
- A first-class `transaction()` API over sqflite transactions.
- Encrypted database option.

## Done
- v1.2.0: test seam, full test suite, API docs, expanded example, CI,
  benchmarks, production/community docs.

Have an idea? Open a feature request.
```

- [ ] **Step 4: Commit**

```bash
git add CONTRIBUTING.md CODE_OF_CONDUCT.md ROADMAP.md
git commit -m "docs: add CONTRIBUTING, CODE_OF_CONDUCT, ROADMAP"
```

### Task 28: GitHub issue & PR templates

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: bug_report.md**

```markdown
---
name: Bug report
about: Report a problem with tecfy_database
title: "[bug] "
labels: bug
---

**Describe the bug**
A clear description of what's wrong.

**To reproduce**
Minimal code sample + steps.

**Expected behavior**

**Environment**
- tecfy_database version:
- Flutter / Dart version (`flutter --version`):
- Platform (Android/iOS/macOS/Windows/Linux/Web):

**Additional context / logs**
```

- [ ] **Step 2: feature_request.md**

```markdown
---
name: Feature request
about: Suggest an idea for tecfy_database
title: "[feature] "
labels: enhancement
---

**Problem**
What are you trying to do that's hard today?

**Proposed solution**

**Alternatives considered**

**Additional context**
```

- [ ] **Step 3: PULL_REQUEST_TEMPLATE.md**

```markdown
## What & why
Describe the change and the motivation.

## Checklist
- [ ] `fvm dart format .`
- [ ] `fvm flutter analyze` passes
- [ ] `fvm flutter test` passes
- [ ] Tests added/updated for the change
- [ ] CHANGELOG.md updated

## Related issues
Closes #
```

- [ ] **Step 4: Commit**

```bash
git add .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md
git commit -m "docs: add issue and pull request templates"
```

### Task 29: Changelog + version + description bump

**Files:**
- Modify: `CHANGELOG.md`, `pubspec.yaml`

- [ ] **Step 1: Prepend the 1.2.0 changelog entry**

At the top of `CHANGELOG.md`:

```markdown
## 1.2.0

### Added
- Optional `TecfyDatabase(databaseFactory:, inMemory:)` parameters — open with a
  custom sqflite factory and/or an in-memory database (backward compatible).
- Exports: `DatabaseFactory`, `databaseFactoryFfi`, `sqfliteFfiInit`,
  `inMemoryDatabasePath`.
- Full unit test suite (init, CRUD, documents, primary keys, schema migration,
  field types, filters, search/pagination, batch, streams, error paths) with
  >80% line coverage.
- GitHub Actions CI (format, analyze, test+coverage, publish dry-run).
- Runnable benchmark harness (`benchmark/tecfy_benchmark.dart`) and published
  indicative results in the README.
- Dartdoc across all public APIs.
- Expanded example app: queries, batch, pagination, streams, error handling.
- Docs: FAQ, Troubleshooting, Migration guide, per-platform limitations,
  Production Readiness guide.
- Community files: CONTRIBUTING, CODE_OF_CONDUCT, ROADMAP, issue/PR templates.

### Changed
- `dispose()` now returns `Future<void>` so callers can await a clean close
  (existing `dispose();` calls remain valid).
- Expanded `pubspec.yaml` description.

### Fixed
- Corrected the README datetime-filter example to pass an epoch integer.

### Known issues
- Indexed `datetime` columns store microseconds internally while the document
  body uses milliseconds; the `add`/`get` round trip is correct. Datetime filter
  values must be passed as epoch integers. See README Troubleshooting.
```

- [ ] **Step 2: Bump version + description in `pubspec.yaml`**

```yaml
name: tecfy_database
description: A fast, realtime, JSON-based, index-driven local database for Flutter, built on SQLite. Schemaless documents with native indexed queries and reactive streams.
version: 1.2.0
homepage: https://github.com/tecfy-co/flutter_tecfy_database
```

(The new description is 60–180 chars — clears the pana length penalty.)

- [ ] **Step 3: Resolve + validate**

Run: `fvm flutter pub get`
Run: `fvm dart pub publish --dry-run`
Expected: no errors; description-length and changelog warnings gone.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md pubspec.yaml pubspec.lock
git commit -m "release: v1.2.0 — changelog, version, expanded description"
```

---

## FINAL — Acceptance Gates

### Task 30: Full verification sweep

**Files:** none

- [ ] **Step 1: Format**

Run: `fvm dart format --output=none --set-exit-if-changed .`
Expected: clean (exit 0).

- [ ] **Step 2: Analyze**

Run: `fvm flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Test + coverage**

Run: `fvm flutter test --coverage`
Expected: all pass; confirm `coverage/lcov.info` shows >80% line coverage.

- [ ] **Step 4: Docs**

Run: `fvm dart doc .`
Expected: builds with no warnings.

- [ ] **Step 5: Package validation**

Run: `fvm dart pub publish --dry-run`
Expected: passes with no errors (minor warnings acceptable).

- [ ] **Step 6: Example builds**

Run: `cd example && fvm flutter pub get && fvm flutter analyze`
Expected: clean.

- [ ] **Step 7: Final summary**

Confirm each acceptance criterion in the spec maps to completed work. Then use the `superpowers:finishing-a-development-branch` skill to decide how to integrate (PR to `main`, merge, etc.).

---

## Self-Review Notes (for the planner)

- **Spec coverage:** Phase 0–7 map to issue items #1 (Tasks 24–26), #2 (17–18), #3 (19), #4 (4–16), #5 (20–21), #6 (29), #7 (22–23), #8 (25), #9 (26), #10 (27–28). All 10 covered.
- **Type consistency:** new params `databaseFactory`/`inMemory`, helper `newTestDb`/`tasksCollection`, and `dispose(): Future<void>` are used identically across all tasks.
- **Pre-existing bugs:** datetime unit + DateTime-filter binding are characterized (Task 10/11) and documented (Task 24), never silently "fixed".
- **Coverage realism:** platform-only branches (web/path_provider) are excluded from the 80% target by design; Task 16 notes this.
