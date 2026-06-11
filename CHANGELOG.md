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
