part of tecfy_database;

class TecfyDatabase {
  Database? _database;
  final List<TecfyIndexField> _TecfyIndexFields = [];

  List<TecfyListener> listeners = [];

  String? dbName;
  TecfyDatabase({required List<TecfyCollection> collections, this.dbName}) {
    _initDb(collections: collections);
  }

  void _initDb({
    required List<TecfyCollection> collections,
  }) async {
    String path = dbName ?? "tecfy_db.db";
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

  void dispose() async {
    await _database?.close();
    _TecfyIndexFields.clear();
  }

  Future<List<Map<String, dynamic>>?> getDocuments({
    required String collectionName,
    String? groupBy,
    String? orderBy,
  }) async {
    try {
      var result = await _database?.query(collectionName,
              orderBy: orderBy, groupBy: groupBy) ??
          [];

      var data = _returnBody(result);

      return data;
    } catch (e) {
      throw Exception(e);
    }
  }

  int get _primaryKeyIndex =>
      _TecfyIndexFields.indexWhere((element) => element.isPrimaryKey == true);

  String get _primaryKeyFieldName =>
      _primaryKeyIndex == -1 ? 'id' : _TecfyIndexFields[_primaryKeyIndex].name;

  Future<bool> deleteDocument(
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

  Future<void> deleteCollection({required String collectionName}) async {
    try {
      await _database?.execute("DROP TABLE IF EXISTS $collectionName");
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> clearCollection({required String collectionName}) async {
    try {
      await _database?.execute("DELETE FROM $collectionName");
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<bool> updateDocument(
      {required String collectionName,
      required Map<String, dynamic> data,
      Object? Function(Object?)? toEncodableEx,
      ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      var body = _getInsertedBody(data);
      if (body == null || body.isEmpty) {
        throw Exception('Wrong Body');
      }
      if (!data.containsKey(_primaryKeyFieldName)) {
        throw Exception('to update document provide primary key field on it');
      }
      var result = await _database?.update(
        collectionName,
        {
          ...body,
          "tecfy_json_body":
              jsonEncode(data, toEncodable: toEncodableEx ?? _customEncode)
        },
        where: "$_primaryKeyFieldName = ?",
        whereArgs: [data[_primaryKeyFieldName]],
        conflictAlgorithm: conflictAlgorithm,
      );
      print('updated');
      if (result != 0) {
        listeners.where((l) => _isFilterApplied(data, l.filter)).forEach((l) {
          l.sendUpdate();
        });
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> insertDocument(
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
        _sendListersUpdate(collectionName, data);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Stream<List<Map<String, dynamic>>> searchListner(
    String collectionName,
    ITecfyDbFilter filter, {
    String? orderBy,
  }) {
    var listner = StreamController<List<Map<String, dynamic>>>.broadcast();
    listeners.add(
        TecfyListener(this, collectionName, filter, listner, orderBy: orderBy));

    return listner.stream;
  }

  /// Search is Worked for pre-definied indexes
  Future<List<Map<String, dynamic>>> search(
    String collectionName,
    ITecfyDbFilter filter, {
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    List<dynamic> params = [];
    var sql = _filterToString(filter, params);
    print(sql);
    print(params);
    var result = await _database?.query(
      collectionName,
      where: sql,
      whereArgs: params,
      groupBy: groupBy,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return _returnBody(result ?? []);
  }

  void _sendListersUpdate(String collection, dynamic document) {
    listeners.removeWhere((l) => l.notifier.isClosed);
    listeners
        .where((l) =>
            l.collectionName == collection &&
            _isFilterApplied(document, l.filter))
        .forEach((l) {
      l.sendUpdate();
    });
  }

  List<Map<String, dynamic>> _returnBody(List<Map<String, dynamic>> result) {
    var data = result.map((e) {
      var dataEx =
          jsonDecode(e['tecfy_json_body'] as String) as Map<String, dynamic>;
      if (_primaryKeyIndex != -1) {
        dataEx[_TecfyIndexFields[_primaryKeyIndex].name] =
            e[_TecfyIndexFields[_primaryKeyIndex].name];
      } else {
        dataEx['id'] = e['id'];
      }

      return dataEx;
    }).toList();
    var checkList = _TecfyIndexFields.where(
        (element) => element.type.name == FieldTypes.datetime.name).toList();
    if (checkList.isNotEmpty) {
      for (var itemInCheckList in checkList) {
        data = data.map((e) {
          var value = e[itemInCheckList.name];
          e[itemInCheckList.name] = DateTime.fromMillisecondsSinceEpoch(value);
          return e;
        }).toList();
      }
    }

    return data;
  }

  String _filterToString(ITecfyDbFilter filter, List<dynamic> params) {
    if (filter.type == ITecfyDbFilterTypes.filter) {
      var f = filter as TecfyDbFilter;
      if (f.operator == TecfyDbOperators.startwith) {
        params.add('${f.value}%');
      } else if (f.operator == TecfyDbOperators.endwith) {
        params.add('%${f.value}');
      } else if (f.operator == TecfyDbOperators.contains) {
        params.add('%${f.value}%');
      } else {
        params.add(f.value);
      }

      return '${f.field} ${_getFilterOperatorValue(f.operator)} ?';
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

  String _getFilterOperatorValue(TecfyDbOperators operator) {
    switch (operator) {
      case TecfyDbOperators.isEqualTo:
        return '=';

      case TecfyDbOperators.isNotEqualTo:
        return '!=';

      case TecfyDbOperators.isGreaterThan:
        return '>';

      case TecfyDbOperators.isGreaterThanOrEqualTo:
        return '>=';

      case TecfyDbOperators.isLessThan:
        return '<';
      case TecfyDbOperators.islessThanOrEqualTo:
        return '<=';

      case TecfyDbOperators.startwith:
      case TecfyDbOperators.endwith:
      case TecfyDbOperators.contains:
        return 'like';

      default:
        return '';
    }
  }

  dynamic _customEncode(dynamic item) {
    if (item is DateTime) {
      return item.millisecondsSinceEpoch;
    }
    return item;
  }

  Map<String, dynamic>? _getInsertedBody(Map<String, dynamic> data) {
    Map<String, dynamic> result = {};
    for (var TecfyIndexField in _TecfyIndexFields) {
      if (TecfyIndexField.type.name == FieldTypes.boolean.name) {
        var value = data[TecfyIndexField.name] == true ? 1 : 0;
        result[TecfyIndexField.name] = value;
      } else if (TecfyIndexField.type.name == FieldTypes.datetime.name) {
        var value = data[TecfyIndexField.name].millisecondsSinceEpoch;
        result[TecfyIndexField.name] = value;
      } else {
        result[TecfyIndexField.name] = data[TecfyIndexField.name];
      }
    }

    if (result.isEmpty) {
      return null;
    } else {
      return result;
    }
  }

  String _getCommand(TecfyCollection element) {
    String command = "CREATE TABLE IF NOT EXISTS ${element.name}(";
    bool TecfyIndexFieldsExisits = element.TecfyIndexFields != null &&
        (element.TecfyIndexFields?.isNotEmpty ?? false);
    if (element.primaryField != null) {
      _TecfyIndexFields.add(element.primaryField!..isPrimaryKey = true);
      command +=
          "${element.primaryField?.name} ${element.primaryField?.type.name} primary key ${(element.primaryField?.autoIncrement ?? false) ? "AUTOINCREMENT" : ""},";
    } else {
      command += "id integer primary key AUTOINCREMENT not null,";
    }

    if (TecfyIndexFieldsExisits) {
      bool isFirstTime = true;
      for (var singleIndexList in element.TecfyIndexFields!) {
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
    if (TecfyIndexFieldsExisits) {
      for (var singleIndexList in element.TecfyIndexFields!) {
        // assign indexes values
        _TecfyIndexFields.addAll(singleIndexList);
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

  bool _isFilterApplied(Map<String, dynamic> document, ITecfyDbFilter filter) {
    return true;
  }
}
