part of tecfy_database;

class TecfyDatabase {
  Database? _database;
  final Map<String, List<TecfyIndexField>> _columns = {};
  Map<String, List<List<TecfyIndexField>>> _indexs = {};

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

              create column if not exisits department varchar(255) not null,
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
    _columns.clear();
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

      var data = _returnBody(collectionName, result);

      return data;
    } catch (e) {
      throw Exception(e);
    }
  }

  int _primaryKeyIndex(String collectionName) => _columns[collectionName]!
      .indexWhere((element) => element.isPrimaryKey == true);

  String _primaryKeyFieldName(String collectionName) =>
      _primaryKeyIndex(collectionName) == -1
          ? 'id'
          : _columns[collectionName]![_primaryKeyIndex(collectionName)].name;

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
      var body = _getInsertedBody(collectionName, data);
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
      var body = _getInsertedBody(collectionName, data);
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

  Future<List<String>> dbIndexesNames(String tableName) async {
    var result = (await _database?.rawQuery("PRAGMA index_list($tableName);"))
        ?.map((e) => e['name'].toString())
        .toList();
    return result ?? [];
  }

  void _createIndexes(String tableName, List<String> dbIndexesName,
      List<String> newIndexesName) async {
    var indexedNeedToBeCreated = newIndexesName
        .where((element) => !dbIndexesName.contains(element))
        .toList();

    for (var newIndex in (_indexs[tableName] as List)) {
      var indName = _getIndexName(newIndex);
      if (!indexedNeedToBeCreated.contains(indName)) continue;
      await _database?.rawQuery(
          "CREATE INDEX $indName ON $tableName (${newIndex.map((e) => '${e.name}').join(',')});");
    }
  }

  void _dropUnusedIndexes(String tableName, List<String> dbIndexesName,
      List<String> newIndexesName) async {
    var unUsedIndexes = dbIndexesName
        .where((element) => !newIndexesName.contains(element))
        .toList();

    for (var unUsedIndexe in unUsedIndexes) {
      await _database?.rawQuery("DROP INDEX $unUsedIndexe");
    }
  }

  List<String> _getNewIndexesNames(String tableName) {
    List<String> result = [];
    for (var ind in (_indexs[tableName] as List)) {
      result.add(_getIndexName(ind));
    }
    return result;
  }

  String _getIndexName(List<TecfyIndexField> ind) {
    var userIndexeNames = ind
        .map((e) => '${e.name}_${e.type.name}${e.asc ? '_a' : '_d'}')
        .toList();

    return 'idx_' + userIndexeNames.join('_');
  }

  void updateColumns(String tableName) async {
    var dbIndexesName = await dbIndexesNames(tableName);
    var newIndexesName = _getNewIndexesNames(tableName);

    _dropUnusedIndexes(tableName, dbIndexesName, newIndexesName);

    // var dbIndexes =
    //     (await _database?.rawQuery("PRAGMA index_list($tableName);"))
    //         ?.map((e) => e['name'].toString())
    //         .toList();
    // print('=============indexes ${dbIndexes}');
    // var dbColumns =
    //     (await _database?.rawQuery("PRAGMA table_info($tableName);"))
    //         ?.map((e) => TecfyIndexField(
    //             name: e['name'] as String,
    //             type: FieldTypes.values.firstWhere((element) =>
    //                 element.name.toLowerCase() ==
    //                 (e['type'] as String).toLowerCase()),
    //             nullable: e['notnull'] == 1 ? false : true))
    //         .toList();
    // dbColumns?.removeWhere((element) => element.name == 'tecfy_json_body');
    // // remove primary key column
    // dbColumns?.removeWhere((element) => element.name == _primaryKeyFieldName);

    // // for add new value
    // await _addNewValueUpdate(tableName, dbColumns);

    // // for remove old value
    // await _removeOldValueUpdate(tableName, dbColumns, dbIndexes);
    // // var sortedUserIndexes =
    // //     _TecfyIndexFields.sorted((e, b) => e.name.compareTo(b.name));
    // // var sortedDbIndexes = result?.sorted((e, b) => e.name.compareTo(b.name));
    // // for (var i = 0; i < _TecfyIndexFields.length - 1; i++) {
    // //   print('======1${sortedUserIndexes[i]}');
    // //   print('======2${sortedDbIndexes?[i]}');
    // //   if ((sortedUserIndexes[i].name == sortedDbIndexes?[i].name) &&
    // //       sortedUserIndexes[i] != sortedDbIndexes?[i]) {
    // //     await _database?.rawQuery(
    // //         'ALTER TABLE $tableName DROP COLUMN ${sortedDbIndexes?[i].name}');
    // //     await _database?.rawQuery(
    // //         'ALTER TABLE $tableName ADD COLUMN ${sortedUserIndexes[i].name} ${sortedUserIndexes[i].type.name}');
    // //   }
    // // }
    // _createIndexes(tableName, dbIndexesName, newIndexesName);
  }

  Future<void> _removeOldValueUpdate(String tableName,
      List<TecfyIndexField>? dbColumns, List<String>? dbIndexes) async {
    var oldIndexesNamesList = _columns[tableName]?.map((e) => e.name).toList();

    var deletedIndexesList = dbColumns
        ?.where((element) =>
            !(oldIndexesNamesList?.contains(element.name) ?? false))
        .toList();
    if (deletedIndexesList?.isNotEmpty ?? false) {
      for (var deletedIndexe in deletedIndexesList!) {
        var values = dbIndexes
            ?.where((element) => element.contains(deletedIndexe.name))
            .toList();

        for (var value in values ?? []) {
          if (value.split('_').length == 2) {
            await _database?.rawQuery("DROP INDEX idx$value");
          } else {}
        }

        await _database?.rawQuery(
            'ALTER TABLE $tableName DROP COLUMN ${deletedIndexe.name}');

        // var deletedIndexsListEx = _indexs
        //     ?.where((element) => element
        //             .where((elementEx) => elementEx.name == deletedIndexe.name)
        //             .isNotEmpty
        //         ? true
        //         : false)
        //     .toList();

        // var elmentNames = '';

        // for (var deletedIndexsEx in deletedIndexsListEx!) {
        //   for (var deletedIndex in deletedIndexsEx) {
        //     elmentNames += '_${deletedIndex.name}';
        //   }
        //   // await _database?.rawQuery("DROP INDEX idx$elmentNames");
        // }
      }
    }
  }

  Future<void> _addNewValueUpdate(
      String tableName, List<TecfyIndexField>? dbColumns) async {
    var dbColumnNamesList = dbColumns?.map((e) => e.name).toList();
    var newIndexsList = _columns[tableName]
        ?.where(
            (element) => !(dbColumnNamesList?.contains(element.name) ?? false))
        .toList();
    if (newIndexsList?.isNotEmpty ?? false) {
      for (var newIndex in newIndexsList ?? []) {
        await _database?.rawQuery(
            'ALTER TABLE $tableName ADD COLUMN ${newIndex.name} ${newIndex.type.name}');

        var newIndexsListEx = _indexs[tableName]
            ?.where((element) => element
                    .where((elementEx) => elementEx.name == newIndex.name)
                    .isNotEmpty
                ? true
                : false)
            .toList();

        var queryElmentName = '';
        var elmentNames = '';
        bool isFirstTimeEx = true;
        for (var newIndexEx in newIndexsListEx ?? []) {
          for (var newIndex in newIndexEx) {
            if (!isFirstTimeEx) {
              queryElmentName += ",";
            }
            elmentNames += '_${newIndex.name}';
            queryElmentName +=
                "${newIndex.name} ${!newIndex.asc ? "DESC" : ""}";
            isFirstTimeEx = false;
          }
          await _database?.rawQuery(
              "CREATE INDEX idx$elmentNames ON $tableName ($queryElmentName);");
        }
      }
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
    return _returnBody(collectionName, result ?? []);
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

  List<Map<String, dynamic>> _returnBody(
      String tableName, List<Map<String, dynamic>> result) {
    var data = result.map((e) {
      var dataEx =
          jsonDecode(e['tecfy_json_body'] as String) as Map<String, dynamic>;
      if (_primaryKeyIndex != -1) {
        dataEx[_columns[tableName]![_primaryKeyIndex(tableName)].name] =
            e[_columns[tableName]![_primaryKeyIndex(tableName)].name];
      } else {
        dataEx['id'] = e['id'];
      }

      return dataEx;
    }).toList();
    var checkList = _columns[tableName]
        ?.where((element) => element.type.name == FieldTypes.datetime.name)
        .toList();
    if (checkList?.isNotEmpty ?? false) {
      for (var itemInCheckList in checkList ?? []) {
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

  Map<String, dynamic>? _getInsertedBody(
      String tableName, Map<String, dynamic> data) {
    Map<String, dynamic> result = {};
    for (var TecfyIndexField in _columns[tableName] ?? []) {
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
    bool tecfyIndexFieldsExisits = element.tecfyIndexFields != null &&
        (element.tecfyIndexFields?.isNotEmpty ?? false);
    if (element.primaryField != null) {
      _columns[element.name] ??= [];
      _columns[element.name]?.add(element.primaryField!..isPrimaryKey = true);
      command +=
          "${element.primaryField?.name} ${element.primaryField?.type.name} primary key ${(element.primaryField?.autoIncrement ?? false) ? "AUTOINCREMENT" : ""},";
    } else {
      command += "id integer primary key AUTOINCREMENT not null,";
    }

    if (tecfyIndexFieldsExisits) {
      bool isFirstTime = true;
      for (var singleIndexList in element.tecfyIndexFields!) {
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
    // re-check for re create columns
    // if (tecfyIndexFieldsExisits) {
    //   for (var singleIndexList in element.tecfyIndexFields!) {
    //     command += singleIndexList
    //         .where((element) => element.isPrimaryKey == false)
    //         .map((e) =>
    //             "Alter table  ${element.name} Add Column ${e.name} ${e.type.name} ${e.nullable ? "" : 'not null'};")
    //         .join('');
    //   }
    // }

    // create indexes
    if (tecfyIndexFieldsExisits) {
      _indexs[element.name] = element.tecfyIndexFields ?? [];
      for (var singleIndexList in element.tecfyIndexFields!) {
        // assign indexes and columns values

        _columns[element.name] = singleIndexList;
        if (singleIndexList.length == 1) {
          command += singleIndexList
              .map((e) => "CREATE INDEX ${_getIndexName([
                        e
                      ])} ON ${element.name} (${e.name});")
              .toList()
              .join(';');
        } else {
          var elmentNames = "";

          elmentNames += '${_getIndexName(singleIndexList)}';

          command +=
              "CREATE INDEX $elmentNames ON ${element.name} (${singleIndexList.map((e) => "${e.name} ${!e.asc ? "DESC" : ""}").join(',')});";
        }
      }
    }
    //TODO ADD DISTINCT TO LISt
    print(command);
    return command;
  }

  bool _isFilterApplied(Map<String, dynamic> document, ITecfyDbFilter filter) {
    _database?.query('select true if 155>120');
    return true;
  }
}
