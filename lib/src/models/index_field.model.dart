part of '../../tecfy_database.dart';

/// A single indexed field mirrored from your JSON into a real, typed SQLite
/// column. [name] is the JSON key, [type] the storage [FieldTypes], [nullable]
/// toggles NOT NULL, [asc] sets index direction, and [autoIncrement] applies
/// only to an integer primary key.
// ignore: must_be_immutable
class TecfyIndexField with EquatableMixin {
  final String name;
  final FieldTypes type;
  final bool nullable;
  final bool asc;
  final bool autoIncrement;
  bool isPrimaryKey = false;

  TecfyIndexField({
    required this.name,
    required this.type,
    this.nullable = true,
    this.asc = true,
    this.autoIncrement = false,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "type": type.name,
        "nullable": nullable,
        "asc": asc,
        "autoIncrement": autoIncrement,
        "isPrimaryKey": isPrimaryKey,
      };

  @override
  List<Object?> get props => [name, type.name, nullable];
}
