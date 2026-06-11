part of '../../tecfy_database.dart';

/// Declares one collection (SQLite table): its [name], optional [primaryField],
/// and [tecfyIndexFields] (a list of indexes, each a list of fields — a
/// multi-field list is a composite index). Index every field you need to
/// filter/sort/group by; everything else lives in the JSON body.
class TecfyCollection {
  String name;
  TecfyIndexField? primaryField;
  List<List<TecfyIndexField>>? tecfyIndexFields;

  TecfyCollection(this.name, {this.primaryField, this.tecfyIndexFields});

  Map<String, dynamic> toJson() => {
        "name": name,
        "primaryField": primaryField?.toJson(),
        "TecfyIndexFields": tecfyIndexFields
            ?.map((e) => e.map((w) => w.toJson()).toList())
            .toList()
      };
}
