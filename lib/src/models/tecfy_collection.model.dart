part of tecfy_database;

class TecfyCollection {
  String name;
  TecfyIndexField? primaryField;
  List<List<TecfyIndexField>>? TecfyIndexFields;

  TecfyCollection(this.name, {this.primaryField, this.TecfyIndexFields});

  Map<String, dynamic> toJson() => {
        "name": name,
        "primaryField": primaryField?.toJson(),
        "TecfyIndexFields":
            TecfyIndexFields?.map((e) => e.map((w) => w.toJson()).toList())
                .toList()
      };
}
