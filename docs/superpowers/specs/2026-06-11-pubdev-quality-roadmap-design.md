# tecfy_database — pub.dev & Quality Roadmap (v1.2.0)

**Date:** 2026-06-11
**Status:** Approved design, ready for implementation planning
**Target version:** 1.2.0 (minor — backward-compatible public API addition)

## Goal

Raise the package's pub.dev (pana) score and overall quality/maintainability by
executing the full 10-item improvement roadmap. Some roadmap items affect the
algorithmic pana score directly; others improve trust, maintainability, and
community signals. Both categories are in scope.

## Context: current state (already done)

These were flagged in the source issue but are **already substantially complete**
and only need additive touches:

- **README (#1)** — 540 lines: overview, "how it works" architecture diagram,
  feature-comparison table, full API reference, platform matrix, best-practices.
  Needs only: FAQ, Troubleshooting, Migration guide, status badges, benchmark
  table, per-platform limitations.
- **CHANGELOG (#6)** — detailed `1.1.3` entry already in Added/Changed/Fixed
  style. Needs a new `1.2.0` entry.
- **Example (#3)** — runnable todo + users + roles app exists. Needs advanced
  scenarios and a fix to the stale default-counter `widget_test.dart`.
- **Platform support (#8)** — matrix exists. Needs per-platform known limitations.

## Key facts that shaped the design

- The DB handle is a `static Database?` plus a `get_it` singleton
  (`instanceName: 'tecfyDatabase'`). Path resolution uses `path_provider`
  (`getApplicationDocumentsDirectory`) and sqflite's `getDatabasesPath()` —
  platform channels that do **not** exist on the Dart VM / CI runners.
- On Windows/Linux the code already calls `sqfliteFfiInit()` and sets
  `databaseFactory = databaseFactoryFfi`. Path resolution failures are caught and
  fall back to `databasesPath = ""`.
- The package exposes `Batch` (atomic `commitBatch`) but **no `transaction()` API**.
- The public API surface has only ~18 `///` comments across 3 files — well under
  pana's 20% documentation threshold.
- `pubspec.yaml` `description` is 34 chars ("sqlite database as json database.") —
  pana penalizes descriptions under 60 chars.

## Decisions (locked)

1. **Test seam:** add a backward-compatible seam to make the package
   testable/CI-runnable and give users more control. → version bump to 1.2.0.
2. **Benchmarks:** ship a runnable harness **and** publish indicative numbers in
   the README behind a clear "measured on `<machine>`, your results will vary"
   disclaimer + reproduce instructions.
3. **Transactions:** document `Batch` as the atomic-write mechanism and explicitly
   note there is no separate `transaction()` API. Do **not** add a new feature.

## Architecture: the test seam (Phase 0)

Extend the `TecfyDatabase` constructor with two optional, default-preserving
parameters:

```dart
TecfyDatabase({
  required List<TecfyCollection> collections,
  String? dbName,
  DatabaseFactory? databaseFactory, // NEW — overrides platform detection
  bool inMemory = false,            // NEW — use inMemoryDatabasePath, skip path_provider
});
```

Behavior in `_initDb`:

- If `databaseFactory != null`: set the global sqflite `databaseFactory` to it and
  **skip** the platform-detection / FFI-init branch. Open with
  `inMemory ? inMemoryDatabasePath : (dbName ?? 'tecfy_db.db')`.
- If `inMemory == true` (without a custom factory on a desktop platform): use
  `inMemoryDatabasePath` and skip `path_provider` resolution.
- Otherwise: existing behavior, unchanged.

Export the symbols test code/users need:

```dart
export 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show ConflictAlgorithm, Batch, DatabaseFactory, databaseFactoryFfi,
         sqfliteFfiInit, inMemoryDatabasePath;
```

**Test isolation:** the `static _database` handle is per-isolate. Dart test files
run in separate isolates, and tests within a file run sequentially, so calling
`dispose()` in `tearDown` (which closes the DB, clears the GetIt singleton and
operations) gives each test a fresh database. In-memory DBs created via
`inMemoryDatabasePath` are discarded on close.

`dev_dependencies`: add `flutter_test` (sdk) and uncomment/restore it.

## Phases

Executed in dependency order. Phases 1 and 2 depend on Phase 0; the rest are
largely independent.

### Phase 0 — Baseline & test seam (code)
- Implement the constructor seam + exports above.
- Restore `flutter_test` to `dev_dependencies`.
- Confirm `flutter analyze` clean; record baseline output.

### Phase 1 — Unit tests (#4) — depends on Phase 0
Top-level `test/` suite. Each test sets up FFI (`sqfliteFfiInit()`) and an
in-memory `TecfyDatabase`, and disposes in `tearDown`. Coverage:
- DB init / `isReady`, re-init after `dispose`, missing-collection throw.
- Collection CRUD: `add` (default + explicit id), `get`, `clear`.
- Document ops: `doc(id).get/update/delete`, `exists`.
- Primary keys: default `id` autoincrement, custom `primaryField`, PK-change drops table.
- Schema migration: add index field (backfill column), remove index field (drop column), add/remove index.
- Field types round-trip: integer, real, text, blob, boolean, datetime.
- Filters: every operator (`isEqualTo`…`isNull`, `startWith`/`endWith`/`contains`, `arrayIn`) + nested `TecfyDbAnd`/`TecfyDbOr`.
- `search`/`searchCount`/`searchAny`, `groupBy`/`having`/`orderBy`, pagination (`limit`/`offset`).
- Batch: `getBatch`, queued add/update/delete, `commitBatch` notifies once.
- Streams: collection `stream`, doc `stream`, `count`; refresh on notifying write; `refreshListers`.
- Error paths: UNIQUE constraint → `add` returns `false`; ops on uninitialized DB throw.

Target: **>80% line coverage**, measured by `flutter test --coverage` + lcov.

### Phase 2 — API documentation (#2) — depends on Phase 0
Add `///` dartdoc (description, params, returns, short example) to every public
symbol: `TecfyDatabase`, `TecfyCollection`, `TecfyIndexField`, `FieldTypes`,
`TecfyCollectionOperations`, `TecfyDocumentOperations`, `TecfyDbFilter`,
`TecfyDbAnd`, `TecfyDbOr`, `TecfyDbOperators`, and the library directive.
Gate: `dart doc` generates with **no warnings**; coverage clears pana's 20%.

### Phase 3 — Expand example app (#3)
Restructure `example/` into a gallery demonstrating: complex queries (nested
AND/OR, all operators), indexing strategies (single vs composite), batch
operations, **Batch as the atomic mechanism (with explicit "no `transaction()`
API" note)**, filtering, pagination, stream subscriptions (collection + doc +
count), and error handling. Fix the stale counter `widget_test.dart`. Keep
`cd example && flutter run` working.

### Phase 4 — CI (#5)
`.github/workflows/ci.yml` on push/PR (Linux runner, FFI):
`flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` →
`flutter test --coverage` → `dart pub publish --dry-run`. Add README status
badges (CI, pub version, pub points/likes, license).

### Phase 5 — Benchmarks (#7)
`benchmark/` harness (runnable, in-memory for reproducibility) timing
insert/update/delete/query and **indexed vs non-indexed** query. Publish an
indicative results table in the README with the machine/OS/Flutter-version
disclaimer + reproduce instructions.

### Phase 6 — Docs: README additions, platform notes, production guide (#1, #8, #9)
- README: add **FAQ**, **Troubleshooting**, **Migration guide** sections.
- Platform matrix: add per-platform **known limitations** (Web WASM binaries,
  Windows path handling, no native plugin code, etc.).
- `doc/production_readiness.md` (#9): recommended DB sizes, indexing best
  practices, backup strategy (copy the DB file), migration strategy, performance
  considerations. Linked from README.

### Phase 7 — Community files + changelog/version (#10, #6)
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `ROADMAP.md`,
  `.github/ISSUE_TEMPLATE/` (bug + feature), `.github/PULL_REQUEST_TEMPLATE.md`.
- CHANGELOG: detailed `1.2.0` entry (Added / Changed / Fixed / Deprecated /
  Removed).
- `pubspec.yaml`: bump version → `1.2.0`; rewrite `description` to ~60–180 chars.

## Cross-cutting acceptance gates

- `flutter analyze` — no issues.
- `dart format --set-exit-if-changed .` — clean.
- `flutter test --coverage` — green, **>80%** line coverage.
- `dart doc` — builds with no warnings.
- `dart pub publish --dry-run` — passes with no errors and minimal warnings.

## Out of scope

- No new runtime features beyond the test seam (no `transaction()` API, no
  query-engine changes).
- Benchmark numbers are indicative, not guarantees.
- Actual pub.dev likes/downloads can't be changed directly — only the trust
  signals that influence them.

## Risks

- **Behavior regression from the seam.** Mitigated by keeping all new params
  optional with defaults that preserve current branches, plus the new test suite.
- **`arrayIn` / `isNull` filter SQL** has commented-out param handling and builds
  values inline — tests must assert current behavior and flag any SQL-injection /
  correctness concern rather than silently "fixing" it mid-roadmap.
- **Coverage target.** Some platform-path branches can't run on CI; the seam
  routes around them so the testable surface still clears 80%.
