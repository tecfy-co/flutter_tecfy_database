part of tecfy_database;

class TecfyIndexField {
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
  Map<String, dynamic> toJsonEx() => {
        "name": name,
        "type": type.name.toLowerCase(),
        "notnull": nullable == true ? 0 : 1,
      };
}
