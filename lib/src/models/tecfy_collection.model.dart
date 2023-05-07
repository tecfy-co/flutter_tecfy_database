part of tecfy_database;

class TecfyCollection {
  String name;
  IndexField? primaryField;
  List<List<IndexField>>? indexFields;

  TecfyCollection(this.name, {this.primaryField, this.indexFields});

  Map<String, dynamic> toJson() => {
        "name": name,
        "primaryField": primaryField?.toJson(),
        "indexFields":
            indexFields?.map((e) => e.map((w) => w.toJson()).toList()).toList()
      };
}
