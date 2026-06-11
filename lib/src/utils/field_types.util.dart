part of '../../tecfy_database.dart';

/// Supported index-field storage types. `boolean` is stored as 1/0 and
/// `datetime` as an epoch integer; both convert back automatically on read.
enum FieldTypes { integer, real, text, blob, boolean, datetime }
