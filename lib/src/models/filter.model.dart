part of '../../tecfy_database.dart';

/// Base type for query filters. Use [TecfyDbFilter], [TecfyDbAnd] or [TecfyDbOr].
abstract class ITecfyDbFilter {
  late ITecfyDbFilterTypes type;
  ITecfyDbFilter(this.type);
}

/// A single condition: `field operator value` (e.g. age > 18). [field] must be
/// an indexed column.
class TecfyDbFilter extends ITecfyDbFilter {
  late String field;
  late TecfyDbOperators operator;

  dynamic value;
  TecfyDbFilter(this.field, this.operator, this.value)
      : super(ITecfyDbFilterTypes.filter);
}

/// Matches when ALL nested filters match.
class TecfyDbAnd extends ITecfyDbFilter {
  late List<ITecfyDbFilter> filters;
  TecfyDbAnd(this.filters) : super(ITecfyDbFilterTypes.and);
}

/// Matches when ANY nested filter matches.
class TecfyDbOr extends ITecfyDbFilter {
  late List<ITecfyDbFilter> filters;
  TecfyDbOr(this.filters) : super(ITecfyDbFilterTypes.or);
}

/// Comparison operators for [TecfyDbFilter]. `startWith`/`endWith`/`contains`
/// map to SQL LIKE; `arrayIn` maps to IN; `isNull` checks NULL (`value: true`
/// = is null, `false` = is not null).
enum TecfyDbOperators {
  isNull,
  isEqualTo,
  isNotEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  startWith,
  endWith,
  contains,
  arrayIn,
}

enum ITecfyDbFilterTypes { filter, and, or }
