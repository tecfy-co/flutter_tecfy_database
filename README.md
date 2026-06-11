# Tecfy Database

[![CI](https://github.com/tecfy-co/flutter_tecfy_database/actions/workflows/ci.yml/badge.svg)](https://github.com/tecfy-co/flutter_tecfy_database/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/tecfy_database.svg)](https://pub.dev/packages/tecfy_database)
[![pub points](https://img.shields.io/pub/points/tecfy_database)](https://pub.dev/packages/tecfy_database/score)
[![License](https://img.shields.io/badge/license-see%20LICENSE-blue.svg)](LICENSE)

A fast, **realtime**, **JSON‑based**, **index‑driven** database for Flutter — built on top of SQLite.

Store plain Dart `Map<String, dynamic>` documents like you would in a NoSQL store (Firestore‑style `collection` / `doc` API), while getting the raw speed of native SQLite indexes for the fields you actually query on. It runs everywhere Flutter does: **Android, iOS, macOS, Windows, Linux, and Web**.

---

## Table of contents

- [Why Tecfy Database?](#why-tecfy-database)
- [How it works (the core idea)](#how-it-works-the-core-idea)
- [Installation](#installation)
- [Web setup](#web-setup)
- [Quick start](#quick-start)
- [Defining collections](#defining-collections)
  - [Index fields & composite indexes](#index-fields--composite-indexes)
  - [Primary keys](#primary-keys)
  - [Field types](#field-types)
- [Writing data](#writing-data)
- [Reading data](#reading-data)
- [Querying & filters](#querying--filters)
- [Realtime streams](#realtime-streams)
- [Batch operations](#batch-operations)
- [Schema changes & automatic migration](#schema-changes--automatic-migration)
- [API reference](#api-reference)
- [Benchmarks](#benchmarks)
- [Best practices & gotchas](#best-practices--gotchas)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Migration guide](#migration-guide)
- [Platform support](#platform-support)

---

## Why Tecfy Database?

Most local database choices force a trade‑off:

| Approach | Flexible schema | Fast indexed queries | Realtime updates |
|----------|:--------------:|:--------------------:|:----------------:|
| Raw SQLite | ❌ rigid columns | ✅ | ❌ |
| Key/value (Hive, shared_prefs) | ✅ | ❌ (full scans) | ⚠️ limited |
| **Tecfy Database** | ✅ | ✅ | ✅ |

Tecfy Database gives you all three: schemaless JSON documents, SQLite‑backed indexed lookups, and reactive `Stream`s that plug straight into a Flutter `StreamBuilder`.

---

## How it works (the core idea)

Every collection is a real SQLite table. Each document you insert is stored **in full** as JSON inside a hidden `tecfy_json_body` text column. That's what makes the store schemaless — you can put any shape of `Map` in and get the exact same `Map` back.

On top of that, you declare a handful of **index fields**. Each index field is materialized as a *real, typed, indexed SQLite column* that mirrors a value from your JSON. This is the "performance‑driven, index‑driven" part:

```
Document you write:                  How it is stored in the "users" table:
{                                    ┌──────────┬──────────────┬───────────────────────────────┐
  "name": "Sara",                    │ name     │ createdAt    │ tecfy_json_body               │
  "mobile": "0100...",      ──────►  │ (indexed)│ (indexed)    │ (full JSON document)          │
  "createdAt": <DateTime>,           ├──────────┼──────────────┼───────────────────────────────┤
  "address": { "city": "Cairo" }     │ "Sara"   │ 1717000000.. │ {"name":"Sara","mobile":...}  │
}                                     └──────────┴──────────────┴───────────────────────────────┘
       indexed columns ◄─── duplicated ───┘                ▲
                                                           └─ everything (including non-indexed
                                                              fields like "address") lives here
```

The practical consequences — read these, they explain everything below:

1. **Queries (`search`, `filter`, `orderBy`, `groupBy`, `count`) run against the indexed columns**, so they are backed by SQLite B‑tree indexes and stay fast as the table grows.
2. **You can only filter / sort / group by fields you declared as index fields.** Non‑indexed fields exist only inside the JSON body, so they are returned in your documents but are *not* directly queryable.
3. **Reads always return your original document** (decoded from the JSON body), with the primary‑key value merged in — not just the indexed columns.

So the design rule is simple: **index the fields you query on, leave everything else in the document.**

### Realtime

Collection and document `stream()`s register a listener on that collection. Whenever a write happens with notifications enabled (`add(..., notify: true)`, `update(..., notifier: true)`, `delete(..., notifier: true)`, or `commitBatch(..., notify: true)`), Tecfy re‑runs the relevant query and pushes fresh results to every open stream for that collection. This is what powers live `StreamBuilder` UIs without any manual refresh.

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  tecfy_database: ^1.1.0
```

Or pull it directly from Git:

```yaml
dependencies:
  tecfy_database:
    git:
      url: https://github.com/tecfy-co/flutter_tecfy_database.git
```

Then:

```bash
flutter pub get
```

No extra setup is required for **Android, iOS, macOS, Windows, or Linux** — the right SQLite backend is selected automatically at runtime.

---

## Web setup

On the web, SQLite runs through WebAssembly, so you must ship two binaries in your app's `web/` folder:

- `sqlite3.wasm`
- `sqflite_sw.js`

Follow the official setup guide and copy the matching binary versions into `web/`:

> https://github.com/tekartik/sqflite/tree/master/packages_web/sqflite_common_ffi_web#setup-binaries

---

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tecfy_database/tecfy_database.dart';

late TecfyDatabase db;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Declare your collections and which fields should be indexed.
  db = TecfyDatabase(
    dbName: 'app.db', // optional, defaults to "tecfy_db.db"
    collections: [
      TecfyCollection('tasks', tecfyIndexFields: [
        [TecfyIndexField(name: 'title',     type: FieldTypes.text, nullable: false)],
        [TecfyIndexField(name: 'isDone',    type: FieldTypes.boolean, asc: false)],
        [TecfyIndexField(name: 'createdAt', type: FieldTypes.datetime, asc: false)],
      ]),
    ],
  );

  // 2. Wait until the database file is opened and tables are ready.
  await db.isReady();

  runApp(const MyApp());
}

// 3. Write a document — any JSON-shaped Map works.
await db.collection('tasks').add(data: {
  'title': 'Buy milk',
  'isDone': false,
  'createdAt': DateTime.now(),
  'notes': {'priority': 'high'}, // non-indexed nested data is fine
});

// 4. Render it live with a StreamBuilder — UI updates automatically on every write.
StreamBuilder<List<Map<String, dynamic>>>(
  stream: db.collection('tasks').stream(orderBy: 'createdAt DESC'),
  builder: (context, snapshot) {
    final tasks = snapshot.data ?? [];
    return ListView(
      children: [for (final t in tasks) ListTile(title: Text(t['title']))],
    );
  },
);
```

---

## Defining collections

A `TecfyCollection` maps to one SQLite table. You declare them once, up front, when constructing `TecfyDatabase`:

```dart
TecfyDatabase(
  collections: [
    TecfyCollection('tasks', tecfyIndexFields: [...]),
    TecfyCollection('users', tecfyIndexFields: [...]),
    TecfyCollection('roles'), // no indexes — pure JSON store, queryable only by id
  ],
);
```

A collection with **no** index fields still works perfectly as a document store; you just can't `search`/`filter` on its contents (only `get`, `doc(id)`, and `exists(id)`).

### Index fields & composite indexes

`tecfyIndexFields` is a **list of indexes**, where each index is itself a **list of fields**. A single‑element list creates a single‑column index; a multi‑element list creates a **composite (multi‑column) index**:

```dart
TecfyCollection('tasks', tecfyIndexFields: [
  // Composite index on (title, desc) — great for queries that filter/sort by both.
  [
    TecfyIndexField(name: 'title', type: FieldTypes.text, nullable: false),
    TecfyIndexField(name: 'desc',  type: FieldTypes.integer),
  ],

  // Single-column index, sorted descending.
  [TecfyIndexField(name: 'isDone', type: FieldTypes.boolean, asc: false)],

  // Single-column datetime index, newest first.
  [TecfyIndexField(name: 'createdAt', type: FieldTypes.datetime, asc: false)],
]);
```

Every field named in any index becomes a real column. A field name only ever creates one column even if it appears in multiple indexes.

`TecfyIndexField` options:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `name` | _required_ | The JSON key to mirror into a column. |
| `type` | _required_ | One of the [`FieldTypes`](#field-types). |
| `nullable` | `true` | If `false`, adds a `NOT NULL` constraint. |
| `asc` | `true` | Index sort direction (`false` = descending). |
| `autoIncrement` | `false` | Only meaningful on an integer [primary key](#primary-keys). |

### Primary keys

By default, every collection gets an auto‑incrementing integer primary key called `id`. After inserting, that `id` is included in the documents you read back:

```dart
final tasks = await db.collection('tasks').get();
print(tasks.first!['id']); // 1, 2, 3, ...
```

To use your own primary key (e.g. a UUID or a server id), pass a `primaryField`:

```dart
TecfyCollection(
  'users',
  primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
  tecfyIndexFields: [
    [TecfyIndexField(name: 'name', type: FieldTypes.text, nullable: false)],
  ],
);

await db.collection('users').add(data: {'uid': 'u_123', 'name': 'Sara'});
await db.collection('users').doc('u_123').get(); // look up by your key
```

The primary‑key field is always returned in your documents, keyed by its name (`uid` above, or `id` by default).

### Field types

```dart
enum FieldTypes { integer, real, text, blob, boolean, datetime }
```

| Type | Dart value you write | How it is stored / read back |
|------|----------------------|------------------------------|
| `integer` | `int` | stored as INTEGER |
| `real` | `double` | stored as REAL |
| `text` | `String` | stored as TEXT |
| `blob` | `List<int>` | stored as BLOB |
| `boolean` | `bool` | stored as `1`/`0`, read back as `bool` |
| `datetime` | `DateTime` | stored as epoch integer, read back as `DateTime` |

`boolean` and `datetime` are converted automatically in both directions, so you work with real `bool` and `DateTime` values in your code. Anything not declared as an index field is serialized as part of the JSON body using Dart's `jsonEncode` (with `DateTime` encoded to epoch milliseconds). For custom types, pass a `toEncodableEx` callback to `add`/`update`.

---

## Writing data

```dart
final tasks = db.collection('tasks');

// Insert. Returns true on success, false if a UNIQUE constraint blocks it.
final ok = await tasks.add(data: {
  'title': 'Write docs',
  'isDone': false,
  'createdAt': DateTime.now(),
});

// Update by primary key. `notifier: true` pushes the change to open streams.
await tasks.doc(taskId).update(
  data: {'title': 'Write docs', 'isDone': true, 'createdAt': DateTime.now()},
  notifier: true,
);

// Delete by primary key.
await tasks.doc(taskId).delete(notifier: true);

// Clear an entire collection (deletes all rows, keeps the table/schema).
await tasks.clear();
```

> **Note on updates:** `update` replaces the stored document with the `data` you pass. Read the existing document first (`await doc(id).get()`) and merge if you want a partial update.

By default `add` notifies listeners (`notify: true`); `update` and `delete` do **not** (`notifier: false`) unless you opt in. Set the flag when you want a write to refresh live `stream()`s.

---

## Reading data

```dart
final col = db.collection('users');

// Get every document (optionally ordered / grouped by an indexed column).
final all = await col.get(orderBy: 'name ASC');

// Get one document by primary key.
final user = await col.doc('u_123').get(); // Map<String, dynamic>?

// Existence check by primary key.
final has = await col.exists('u_123'); // bool
```

---

## Querying & filters

Filters are built from three composable types:

- `TecfyDbFilter(field, operator, value)` — a single condition.
- `TecfyDbAnd([...])` — all conditions must match.
- `TecfyDbOr([...])` — any condition matches.

`TecfyDbAnd` / `TecfyDbOr` can be nested arbitrarily.

```dart
// Simple condition
final done = await db.collection('tasks').search(
  filter: TecfyDbFilter('isDone', TecfyDbOperators.isEqualTo, true),
  orderBy: 'createdAt DESC',
  limit: 20,
);

// Combined: title starts with "Re" AND created after a date.
// NOTE: datetime index columns compare as epoch ints — pass millisecondsSinceEpoch.
final recentReplies = await db.collection('tasks').search(
  filter: TecfyDbAnd([
    TecfyDbFilter('title', TecfyDbOperators.startWith, 'Re'),
    TecfyDbFilter('createdAt', TecfyDbOperators.isGreaterThan,
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch),
  ]),
);

// Nested AND / OR
final filter = TecfyDbOr([
  TecfyDbFilter('isDone', TecfyDbOperators.isEqualTo, true),
  TecfyDbAnd([
    TecfyDbFilter('title', TecfyDbOperators.contains, 'urgent'),
    TecfyDbFilter('desc',  TecfyDbOperators.isNotEqualTo, null),
  ]),
]);
```

### Operators

| Operator | SQL | Notes |
|----------|-----|-------|
| `isEqualTo` | `=` | |
| `isNotEqualTo` | `!=` | |
| `isGreaterThan` | `>` | |
| `isGreaterThanOrEqualTo` | `>=` | |
| `isLessThan` | `<` | |
| `isLessThanOrEqualTo` | `<=` | |
| `startWith` | `LIKE 'value%'` | prefix match |
| `endWith` | `LIKE '%value'` | suffix match |
| `contains` | `LIKE '%value%'` | substring match |
| `arrayIn` | `IN (...)` | `value` is a `List` |
| `isNull` | `IS NULL` / `IS NOT NULL` | `value: true` → is null, `value: false` → is not null |

### Search variants

```dart
// Full result list
Future<List<Map<String, dynamic>>> search({filter, groupBy, having, orderBy, limit, offset});

// Count matching rows
Future<int?> searchCount({filter});

// Cheap existence check (LIMIT 1)
Future<bool> searchAny({filter});
```

> **Remember:** `field`, `orderBy`, and `groupBy` must reference **indexed columns**. Fields that live only inside the JSON body are not queryable.

---

## Realtime streams

Streams are broadcast `Stream`s that re‑emit whenever the collection changes (via a notifying write). They are the natural fit for Flutter's `StreamBuilder`.

```dart
// Live list, with optional filter + ordering
Stream<List<Map<String, dynamic>>> tasks =
    db.collection('tasks').stream(
      filter: TecfyDbFilter('isDone', TecfyDbOperators.isEqualTo, false),
      orderBy: 'createdAt DESC',
    );

// Live count
Stream<int> openCount = db.collection('tasks').count(
  filter: TecfyDbFilter('isDone', TecfyDbOperators.isEqualTo, false),
);

// Live single document
Stream<Map<String, dynamic>> task = db.collection('tasks').doc(taskId).stream();
```

```dart
StreamBuilder<int>(
  stream: db.collection('tasks').count(),
  builder: (_, snap) => Text('Total tasks: ${snap.data ?? 0}'),
);
```

For a stream to refresh, the write that changed the data must notify:

- `add(data: ...)` → notifies by default.
- `update(data: ..., notifier: true)` and `delete(notifier: true)` → opt in.
- `commitBatch(batch: ..., notify: true)` → opt in (default `true`).
- `collection.refreshListers()` → manually force a refresh of all of a collection's streams.

---

## Batch operations

For bulk writes, use a single SQLite batch so everything commits together — far faster than many individual awaits, and it only fires one notification.

```dart
final col = db.collection('tasks');
final batch = col.getBatch();

for (final item in incoming) {
  await col.add(data: item, batch: batch);              // queued, not yet written
}
await col.doc(id).update(data: {...}, batch: batch);     // queued
await col.doc(oldId).delete(batch: batch);               // queued

// Commit everything atomically, then notify streams once.
await col.commitBatch(batch: batch, notify: true);
```

When you pass a `batch`, the operation is queued onto it instead of executing immediately, and per‑operation notifications are suppressed until `commitBatch` runs.

---

## Schema changes & automatic migration

When the app starts, Tecfy compares the index fields you declared against what's already in the SQLite file and reconciles them automatically:

- **New index field** → adds the column and (re)builds its index, backfilling values from existing JSON bodies.
- **Removed index field** → drops the now‑unused column.
- **Index added/removed** → creates or drops the corresponding SQLite index.
- **Primary key changed** → the table is dropped and recreated.

This means you can evolve your indexes between releases just by editing your `TecfyCollection` declarations.

> ⚠️ Dropping an index field removes its column, and **changing the primary key drops the table** (its rows are lost). Plan primary‑key changes carefully and migrate data yourself if you need to preserve it. Your non‑indexed document data is always safe in the JSON body as long as the table isn't dropped.

---

## API reference

### `TecfyDatabase`

```dart
TecfyDatabase({required List<TecfyCollection> collections, String? dbName});

Future<bool> isReady();              // resolves once the DB file is open & ready
TecfyCollectionOperations collection(String name);  // throws if not declared
Future<void> clearDb();              // delete all rows in every collection
void dispose();                      // close the database
```

> Always `await db.isReady()` before your first read/write (e.g. in `main()` before `runApp`).

### Collection — `db.collection(name)`

```dart
Future<bool>                        add({required data, toEncodableEx, nullColumnHack, conflictAlgorithm, notify = true, batch});
Future<List<Map<String, dynamic>?>> get({orderBy, groupBy});
Future<List<Map<String, dynamic>>>  search({filter, groupBy, having, orderBy, limit, offset});
Future<int?>                        searchCount({filter});
Future<bool>                        searchAny({filter});
Future<bool>                        exists(dynamic id);
Future<bool>                        clear();                // delete all docs in this collection
Stream<List<Map<String, dynamic>>>  stream({filter, orderBy});
Stream<int>                         count({filter});
TecfyDocumentOperations             doc([dynamic id]);
Batch?                              getBatch();
Future<List<Object?>?>              commitBatch({required batch, notify = true, exclusive, noResult, continueOnError});
void                               refreshListers();        // force-refresh this collection's streams
```

### Document — `db.collection(name).doc(id)`

```dart
Future<Map<String, dynamic>?>      get();
Future<bool>                       update({required data, toEncodableEx, conflictAlgorithm, batch, notifier = false});
Future<bool>                       delete({notifier = false, batch});
Stream<Map<String, dynamic>>       stream({filter, orderBy});
```

---

## Benchmarks

> ⚠️ Indicative numbers only. Measured with the in-memory FFI backend
> (`benchmark/tecfy_benchmark.dart`) on Flutter 3.44.1 / Dart 3.12.1 (Windows
> desktop). Your results will vary with hardware, payload size, and platform.

| Operation | Count | Time | Per op |
|-----------|------:|-----:|-------:|
| Batch insert | 5,000 docs | `229` ms | `0.046` ms/doc |
| Indexed point query | 1,000 | `254` ms | `0.254` ms/query |
| Full-scan lookup (no index) | 200 | `1223` ms | `6.115` ms/lookup |
| Update | 1,000 | `214` ms | `0.214` ms/op |
| Delete | 1,000 | `188` ms | `0.188` ms/op |

Reproduce: `flutter test benchmark/tecfy_benchmark.dart`

**Takeaways:** batched writes are dramatically faster than per-document awaits,
and indexed point queries are far cheaper per lookup than scanning every row.
Querying a non-indexed field isn't supported — declare an index for anything you
filter or sort on.

---

## Best practices & gotchas

- **Index what you query, nothing more.** Each index field adds a column + index (write cost + storage). Fields you only ever read can stay in the JSON body.
- **You can't filter/sort by non‑indexed fields.** If you need to query a field, declare it as an index field — even a single‑column index is enough.
- **`update` replaces the document.** Merge with the current value yourself for partial updates.
- **Set `notify`/`notifier` for live UIs.** `update`/`delete` don't refresh streams unless you opt in.
- **Use batches for bulk writes.** One `commitBatch` is dramatically faster and emits a single notification.
- **`add` returns `false` on a UNIQUE constraint** instead of throwing — check the result when inserting with unique keys.
- **Always `await db.isReady()`** before the first operation.

---

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
- Bug fixes: custom (non-`id`) primary keys now work for `doc()` lookups and
  read-back; `searchCount()`/`searchAny()`/`count()` with no filter now count
  all rows (previously returned 0).

---

## Platform support

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

---

## Example

A complete, runnable example (todo + users + roles, with realtime lists, search, and updates) lives in the [`/example`](example/) folder.

```bash
cd example
flutter run
```

---

## License

See the repository for license details: <https://github.com/tecfy-co/flutter_tecfy_database>
