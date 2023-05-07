part of tecfy_database;

class TecfyDbServices {
  static Database? _database;
  static final List<IndexField> _indexFields = [];
  static void initDb({
    required List<TecfyCollection> collections,
  }) async {
    String path = "tecfy_db.db";
    List<String> executeCommands = [];
    for (var element in collections) {
      executeCommands.add(_getCommand(element));
    }

    try {
      if (kIsWeb) {
        var factory = databaseFactoryFfiWeb;
        _database = await factory.openDatabase(path,
            options: OpenDatabaseOptions(
                version: 3,
                onCreate: (db, version) async {
                  for (var executeCommand in executeCommands) {
                    await db.execute(executeCommand);
                  }
                  print("Table Created");
                }));
      } else {
        String databasesPath = await getDatabasesPath();
        String dbPath = '${databasesPath}path';
        _database = await openDatabase(dbPath, version: 3,
            onCreate: (db, version) async {
          // When creating the db, create the table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS students(
                  id primary key,
                  name varchar(255) not null,
                  roll_no int not null,
                  address varchar(255) not null
              );
          ''');
          print("Table Created");
        });
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<List<Map<String, dynamic>>?> getDocuments({
    required String collectionName,
    String? groupBy,
    String? orderBy,
  }) async {
    try {
      var result = await _database?.query(collectionName,
              orderBy: orderBy, groupBy: groupBy) ??
          [];

      var data = result.map((e) {
        var data =
            jsonDecode(e['tecfy_json_body'] as String) as Map<String, dynamic>;
        if (primaryKeyIndex != -1) {
          data[_indexFields[primaryKeyIndex].name] =
              e[_indexFields[primaryKeyIndex].name];
        } else {
          data['id'] = e['id'];
        }

        return data;
      }).toList();
      var checkList = _indexFields
          .where((element) => element.type.name == FieldTypes.datetime.name)
          .toList();
      if (checkList.isNotEmpty) {
        for (var itemInCheckList in checkList) {
          data = data.map((e) {
            var value = e[itemInCheckList.name];
            e[itemInCheckList.name] =
                DateTime.fromMillisecondsSinceEpoch(value);
            return e;
          }).toList();
        }
      }

      return data;
    } catch (e) {
      throw Exception(e);
    }
  }

  static int get primaryKeyIndex =>
      _indexFields.indexWhere((element) => element.isPrimaryKey == true);

  static String get primaryKeyFieldName =>
      primaryKeyIndex == -1 ? 'id' : _indexFields[primaryKeyIndex].name;

  static Future<bool> deleteDocument(
      {required String collectionName,
      required String queryField,
      required dynamic queryFieldValue}) async {
    try {
      var result = await _database?.delete(collectionName,
          where: "$queryField = ?", whereArgs: [queryFieldValue]);
      if (result != 0) {
        return true;
      } else {
        return false;
      }
    } catch (err) {
      throw Exception(err);
    }
  }

  static Future<void> deleteCollection({required String collectionName}) async {
    try {
      await _database?.execute("DROP TABLE IF EXISTS $collectionName");
    } catch (e) {
      throw Exception(e);
    }
  }

  static Future<void> clearCollection({required String collectionName}) async {
    try {
      await _database?.execute("DELETE FROM $collectionName");
    } catch (e) {
      throw Exception(e);
    }
  }

  static Future<bool> updateDocument(
      {required String collectionName,
      required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      var body = _getInsertedBody(data);
      if (body == null || body.isEmpty) {
        throw Exception('Wrong Body');
      }
      if (!data.containsKey(primaryKeyFieldName)) {
        throw Exception('to update document provide primary key field on it');
      }
      var result = await _database?.update(
        collectionName,
        {
          ...body,
          "tecfy_json_body":
              jsonEncode(data, toEncodable: toEncodableEx ?? _customEncode)
        },
        where: "$primaryKeyFieldName = ?",
        whereArgs: [data[primaryKeyFieldName]],
        conflictAlgorithm: conflictAlgorithm,
      );
      print('updated');
      if (result != 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<bool> insertDocument(
      {required String collectionName,
      required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      String? nullColumnHack,
      ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      var body = _getInsertedBody(data);
      var result = await _database?.insert(
        collectionName,
        body != null
            ? {
                ...body,
                "tecfy_json_body": jsonEncode(data,
                    toEncodable: toEncodableEx ?? _customEncode)
              }
            : {
                "tecfy_json_body": jsonEncode(data,
                    toEncodable: toEncodableEx ?? _customEncode)
              },
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
      print('inserted');
      if (result != 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> search(
      String collectionName, ITecfyDbFilter filter) async {
    List<dynamic> params = [];
    var sql = _filterToString(filter, params);
    print(sql);
    print(params);
    _database?.query(collectionName, where: sql, whereArgs: params);
    return [];
  }

  static String _filterToString(ITecfyDbFilter filter, List<dynamic> params) {
    if (filter.type == ITecfyDbFilterTypes.filter) {
      var f = filter as TecfyDbFilter;
      if (f.operator == contains) // like
        params.add('%${f.value}%');
      else
        params.add(f.value);

      // name like '%Ahmed%'
      // name like 'Ahmed%'

      return '${f.field} ${f.operator} ?';
    } else {
      List<String> ands = [];
      var f = filter.type == ITecfyDbFilterTypes.and
          ? (filter as TecfyDbAnd).filters
          : (filter as TecfyDbOr).filters;
      for (var filt in f) {
        ands.add(_filterToString(filt, params));
      }

      return '( ${ands.join(filter.type == ITecfyDbFilterTypes.and ? ' and ' : ' or ')} )';
    }
  }

  static dynamic _customEncode(dynamic item) {
    if (item is DateTime) {
      return item.millisecondsSinceEpoch;
    }
    return item;
  }

  static Map<String, dynamic>? _getInsertedBody(Map<String, dynamic> data) {
    Map<String, dynamic> result = {};
    for (var indexField in _indexFields) {
      if (indexField.type.name == FieldTypes.boolean.name) {
        var value = data[indexField.name] == true ? 1 : 0;
        result[indexField.name] = value;
      } else if (indexField.type.name == FieldTypes.datetime.name) {
        var value = data[indexField.name].millisecondsSinceEpoch;
        result[indexField.name] = value;
      } else {
        result[indexField.name] = data[indexField.name];
      }
    }

    if (result.isEmpty) {
      return null;
    } else {
      return result;
    }
  }

  static String _getCommand(TecfyCollection element) {
    String command = "CREATE TABLE IF NOT EXISTS ${element.name}(";
    bool indexFieldsExisits = element.indexFields != null &&
        (element.indexFields?.isNotEmpty ?? false);
    if (element.primaryField != null) {
      _indexFields.add(element.primaryField!..isPrimaryKey = true);
      command +=
          "${element.primaryField?.name} ${element.primaryField?.type.name} primary key ${(element.primaryField?.autoIncrement ?? false) ? "AUTOINCREMENT" : ""},";
    } else {
      command += "id integer primary key AUTOINCREMENT not null,";
    }

    if (indexFieldsExisits) {
      bool isFirstTime = true;
      for (var singleIndexList in element.indexFields!) {
        if (!isFirstTime) {
          command += ",";
        }
        command += singleIndexList
            .map((e) =>
                "${e.name} ${e.type.name} ${e.nullable ? "" : 'not null'}")
            .join(',');
        isFirstTime = false;
      }
    }
    command += ",tecfy_json_body text);";
    // create indexes
    if (indexFieldsExisits) {
      for (var singleIndexList in element.indexFields!) {
        // assign indexes values
        _indexFields.addAll(singleIndexList);
        if (singleIndexList.length == 1) {
          command += singleIndexList
              .map((e) =>
                  "CREATE INDEX idx_${e.name} ON ${element.name} (${e.name} ${!e.asc ? "DESC" : ""});")
              .toList()
              .join(';');
        } else {
          var elmentNames = "";
          var queryElmentName = "";
          bool isFirstTimeEx = true;

          for (var singleIndex in singleIndexList) {
            if (!isFirstTimeEx) {
              queryElmentName += ",";
            }
            elmentNames += '_${singleIndex.name}';
            queryElmentName +=
                "${singleIndex.name} ${!singleIndex.asc ? "DESC" : ""}";
            isFirstTimeEx = false;
          }
          command +=
              "CREATE INDEX idx$elmentNames ON ${element.name} ($queryElmentName);";
        }
      }
    }

    return command;
  }
}
