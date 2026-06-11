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
  benchmarks, production/community docs, custom-primary-key and null-filter
  count fixes.

Have an idea? Open a feature request.
