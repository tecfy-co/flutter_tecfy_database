part of tecfy_database;

abstract class ITecfyDbFilter {
  late ITecfyDbFilterTypes type;
  ITecfyDbFilter(this.type);
}

class TecfyDbFilter extends ITecfyDbFilter {
  late String field;
  late TecfyDbOperators operator;

  dynamic value;
  TecfyDbFilter(this.field, this.operator, this.value)
      : super(ITecfyDbFilterTypes.filter);
}

class TecfyDbAnd extends ITecfyDbFilter {
  late List<ITecfyDbFilter> filters;
  TecfyDbAnd(this.filters) : super(ITecfyDbFilterTypes.and);
}

class TecfyDbOr extends ITecfyDbFilter {
  late List<ITecfyDbFilter> filters;
  TecfyDbOr(this.filters) : super(ITecfyDbFilterTypes.or);
}

enum TecfyDbOperators {
  isNull,
  isEqualTo,
  isNotEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  isLessThan,
  islessThanOrEqualTo,
  startwith,
  endwith,
  contains,
  arrayIn,
}

enum ITecfyDbFilterTypes { filter, and, or }
