part of '../../tecfy_database.dart';

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
