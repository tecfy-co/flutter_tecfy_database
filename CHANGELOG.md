## 1.2.0

### Added

* Optional `TecfyDatabase(databaseFactory:, inMemory:)` parameters — open with a custom sqflite factory and/or an in-memory database. Fully backward compatible; existing constructors are unaffected.
* New exports: `DatabaseFactory`, `databaseFactoryFfi`, `sqfliteFfiInit`, and `inMemoryDatabasePath` (useful for writing your own tests).
* Full unit test suite (init/isReady, CRUD, document ops, primary keys, schema migration, field types, filters, search/pagination, batch, streams, error paths) with ~90% line coverage.
* GitHub Actions CI: format check, analyze, tests with coverage, and `pub publish` dry-run.
* Runnable benchmark harness (`benchmark/tecfy_benchmark.dart`) with indicative results published in the README.
* Dartdoc comments across the public API.
* Expanded example app into a gallery: complex queries, batch, pagination, realtime streams, and error handling.
* Documentation: FAQ, Troubleshooting, Migration guide, per-platform limitations, and a Production Readiness guide (`doc/production_readiness.md`).
* Community files: `CONTRIBUTING.md`, issue templates, and a pull-request template.
* `.pubignore` to keep internal planning docs and build artifacts out of the published package.

### Changed

* `dispose()` now returns `Future<void>` so callers can `await` a clean close. Existing `dispose();` call sites remain valid.
* Expanded the `pubspec.yaml` `description` and added `repository` / `issue_tracker` metadata.

### Fixed

* **Custom primary keys**: a collection declared with a custom `primaryField` (non-`id`) now resolves correctly for `doc()` lookups, updates, deletes, and read-back. Previously such collections queried/returned the literal `id` column and inserted the key column as `NULL`.
* **No-filter aggregates**: `searchCount()`, `searchAny()`, and the no-filter `count()` stream now count all rows. Previously they built `WHERE null` and always returned `0` / `false`.
* Corrected the README datetime-filter example to pass an epoch integer.

### Known issues

* Indexed `datetime` columns store microseconds internally while the document body uses milliseconds; the `add`/`get` round trip is correct, but `datetime` **filter** values must be passed as epoch integers (`yourDate.millisecondsSinceEpoch`). See the README Troubleshooting section.

## 1.1.3

* `isReady()` now waits until every collection's table and indexes are actually created (fixes "no such table" races on fresh installs).
* Creating a second `TecfyDatabase` instance (e.g. after logout/login) no longer hangs `isReady()` forever; it reuses the open database and rebuilds the collection operations.
* `dispose()` unregisters the GetIt database singleton and clears operations so a later re-init works.
* `commitBatch()` notifies listeners only after the commit completes, so listeners can't re-query before the new rows are visible.
* Export `ConflictAlgorithm` and `Batch` so callers can request upsert behavior without importing sqflite directly.

## 0.0.8

* enhance performance

## 0.0.1

* Describe initial release.
