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

## Running the benchmark
`fvm flutter test benchmark/tecfy_benchmark.dart` (in-memory; prints timings).

## A note on `dart doc`
Generating API docs locally with `dart doc` may crash inside dartdoc 9.0.4
(`RangeError` in `_stripDocImports` during SDK/dependency doc precaching). This
is an upstream dartdoc bug unrelated to this package's doc comments, and it does
not affect `flutter analyze`, the test suite, or `dart pub publish`. If you hit
it, try a newer Dart/dartdoc once a fix lands.

## Commit style
Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `perf:`…).

## Reporting bugs / requesting features
Use the GitHub issue templates. Include Flutter/Dart versions, platform, and a
minimal repro.
