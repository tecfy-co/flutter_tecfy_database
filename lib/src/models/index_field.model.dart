part of tecfy_database;

class IndexField {
  final String name;
  final FieldTypes type;
  final bool nullable;
  final bool asc;
  final bool autoIncrement;
  bool isPrimaryKey = false;

  IndexField({
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
}
