part of tecfy_database;

class TecfyDatabase {
  Database? _database;
  final Map<String, List<TecfyIndexField?>> _columns = {};
  final Map<String, List<TecfyIndexField>> _newcolumns = {};
  final Map<String, List<List<TecfyIndexField>>> _indexs = {};
  bool _loading = true;
  List<TecfyListener> listeners = [];

  String? dbName;
  TecfyDatabase({required List<TecfyCollection> collections, this.dbName}) {
    _initDb(collections: collections);
  }

  void _initDb({
    required List<TecfyCollection> collections,
  }) async {
    String path = dbName ?? "tecfy_db.db";

    try {
      if (kIsWeb) {
        var factory = databaseFactoryFfiWeb;
        _database = await factory.openDatabase(path,
            options: OpenDatabaseOptions(
              version: 3,
            ));

        for (var collection in collections) {
          var createCommand = _getCreationCollectionCommandAndOps(collection);
          await _checkPrimaryKeyChanged(collection.name);
          await _database?.execute(createCommand);
          await updateColumnsAndIndexs(collection.name);
        }

        print("Table Created");
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
      _loading = false;
    } catch (e) {
      print(e);
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
      .indexWhere((element) => element?.isPrimaryKey == true);

  String _primaryKeyFieldName(String collectionName) =>
      _primaryKeyIndex(collectionName) == -1
          ? 'id'
          : _columns[collectionName]![_primaryKeyIndex(collectionName)]!.name;

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
        listeners.where((l) => _filterCheck(l.filter, data)).forEach((l) {
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

  Future<void> _createIndexes(String tableName, List<String> dbIndexesName,
      List<String> newIndexesName) async {
    var indexedNeedToBeCreated = newIndexesName
        .where((element) => !dbIndexesName.contains(element))
        .toList();
    if (indexedNeedToBeCreated.isEmpty) return;
    for (var newIndex in (_indexs[tableName] as List)) {
      var indName = _getIndexName(newIndex);
      if (!indexedNeedToBeCreated.contains(indName)) continue;
      await _database?.rawQuery(
          "CREATE INDEX $indName ON $tableName (${newIndex.map((e) => '${e.name}').join(',')});");
    }
  }

  Future<void> _dropUnusedIndexes(String tableName, List<String> dbIndexesName,
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

  Future<List<TecfyIndexField>?> dbColumnsSpecs(String tableName,
      {bool removePrimarykeyAndJsonColumns = true}) async {
    var dbColumns =
        (await _database?.rawQuery("PRAGMA table_info($tableName);"))
            ?.map((e) => TecfyIndexField(
                name: e['name'] as String,
                type: FieldTypes.values.firstWhere((element) =>
                    element.name.toLowerCase() ==
                    (e['type'] as String).toLowerCase()),
                nullable: e['notnull'] == 1 ? false : true)
              ..isPrimaryKey = e['pk'] == 1 ? true : false)
            .toList();
    if (removePrimarykeyAndJsonColumns) {
      dbColumns?.removeWhere((element) => element.name == 'tecfy_json_body');
      // remove primary key column
      dbColumns?.removeWhere(
          (element) => element.name == _primaryKeyFieldName(tableName));
    }

    return dbColumns;
  }

  Future<void> updateColumnsAndIndexs(String collectionName) async {
    var dbIndexesName = await dbIndexesNames(collectionName);
    var newIndexesName = _getNewIndexesNames(collectionName);
    var dbColumns = await dbColumnsSpecs(collectionName);
    if (_primaryKeyFieldName(collectionName) != 'id') {
      _columns[collectionName]?.removeWhere(
          (element) => element?.name == _primaryKeyFieldName(collectionName));
    }
    await _dropUnusedIndexes(collectionName, dbIndexesName, newIndexesName);

    await _dropOldColumn(collectionName, dbColumns);

    await _createNewColumn(collectionName, dbColumns);

    await _createIndexes(collectionName, dbIndexesName, newIndexesName);
    print('=======db indexes ${dbIndexesName}');
    print('=======db columns ${dbColumns}');

    await _updatedNewColumnsValues(collectionName);
  }

  Future<void> _updatedNewColumnsValues(String collectionName) async {
    if (_newcolumns[collectionName]?.isEmpty ?? false) return;

    var rowValues = await _database?.rawQuery('Select * from $collectionName');

    for (var rowValue in rowValues!) {
      var value = (jsonDecode(rowValue['tecfy_json_body'] as String)
          as Map<String, dynamic>);

      var isUpdated = false;
      for (var newColumn in _newcolumns[collectionName] ?? []) {
        try {
          if (rowValue[newColumn.name] != value[newColumn.name]) {
            rowValue[newColumn.name] == value[newColumn.name];
            isUpdated = true;
          }
        } catch (e) {
          print('Exception : ${e}');
        }
      }
      if (isUpdated) {
        await updateDocument(collectionName: collectionName, data: rowValue);
      }
    }
  }

  Future<void> _dropOldColumn(
      String tableName, List<TecfyIndexField>? dbColumns) async {
    var columnsToBeRemovedList = dbColumns
        ?.where((element) => !(_columns[tableName]!.contains(element)))
        .toList();

    if (columnsToBeRemovedList?.isEmpty ?? false) return;
    for (var columnToBeRemoved in columnsToBeRemovedList ?? []) {
      await _database?.rawQuery(
          'ALTER TABLE $tableName DROP COLUMN ${columnToBeRemoved.name}');
    }
  }

  Future<void> _createNewColumn(
    String tableName,
    List<TecfyIndexField>? dbColumns,
  ) async {
    var newColumnsToBeAddedList = _columns[tableName]
        ?.where((element) => !(dbColumns?.contains(element) ?? false))
        .toList();

    if (newColumnsToBeAddedList?.isEmpty ?? false) return;
    for (var newColumn in newColumnsToBeAddedList!) {
      _newcolumns[tableName] ??= [];
      _newcolumns[tableName]?.add(newColumn!);
      await _database?.rawQuery(
          'ALTER TABLE $tableName ADD COLUMN ${newColumn!.name} ${newColumn.type.name} ${newColumn.nullable ? "" : 'not null'}');
    }
  }

  Stream<List<Map<String, dynamic>>> searchListner(
    String collectionName,
    ITecfyDbFilter filter, {
    String? orderBy,
  }) {
    var listner = StreamController<List<Map<String, dynamic>>>.broadcast();
    var lis =
        TecfyListener(this, collectionName, filter, listner, orderBy: orderBy);
    listeners.add(lis);
    lis.sendUpdate();
    // _sendListersUpdate(collectionName, null);
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
    if (_database == null) throw Exception("Database Not Initlized!");
    List<dynamic> params = [];
    var sql = _filterToString(filter, params);
    print(sql);
    print(params);
    var result = await _database!.query(
      collectionName,
      where: sql,
      whereArgs: params,
      groupBy: groupBy,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return _returnBody(collectionName, result);
  }

  void _sendListersUpdate(String collection, dynamic document) {
    listeners.removeWhere((l) => l.notifier.isClosed);
    listeners
        .where((l) =>
            l.collectionName == collection && _filterCheck(l.filter, document))
        .forEach((l) {
      l.sendUpdate();
    });
  }

  List<Map<String, dynamic>> _returnBody(
      String tableName, List<Map<String, dynamic>> result) {
    var data = result.map((e) {
      var dataEx =
          jsonDecode(e['tecfy_json_body'] as String) as Map<String, dynamic>;
      if (_primaryKeyIndex(tableName) != -1) {
        dataEx[_columns[tableName]![_primaryKeyIndex(tableName)]!.name] =
            e[_columns[tableName]![_primaryKeyIndex(tableName)]!.name];
      } else {
        dataEx['id'] = e['id'];
      }

      return dataEx;
    }).toList();
    var checkList = _columns[tableName]
        ?.where((element) => element?.type.name == FieldTypes.datetime.name)
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

  bool _filterCheck(ITecfyDbFilter filter, Map<String, dynamic> doc) {
    if (filter.type == ITecfyDbFilterTypes.filter) {
      var f = filter as TecfyDbFilter;

      return _filterOperatorValueCheck(f.operator, f.value, doc[f.field]);
    } else {
      List<bool> ands = [];
      var f = filter.type == ITecfyDbFilterTypes.and
          ? (filter as TecfyDbAnd).filters
          : (filter as TecfyDbOr).filters;
      for (var filt in f) {
        ands.add(_filterCheck(filt, doc));
      }
      if (filter.type == ITecfyDbFilterTypes.and) {
        for (var a in ands) {
          if (!a) return false;
        }
        return true;
      } else {
        for (var a in ands) {
          if (a) return true;
        }
        return false;
      }

      // return '( ${ands.join(filter.type == ITecfyDbFilterTypes.and ? ' and ' : ' or ')} )';
    }
  }

// TODO CHAECK OPERATOR PROCESS
  bool _filterOperatorValueCheck(
      TecfyDbOperators operator, dynamic v1, dynamic v2) {
    switch (operator) {
      case TecfyDbOperators.isEqualTo:
        return v1 == v1;

      case TecfyDbOperators.isNotEqualTo:
        return v1 != v1;

      case TecfyDbOperators.isGreaterThan:
        return v1 == v1;

      case TecfyDbOperators.isGreaterThanOrEqualTo:
        return v1 == v1;

      case TecfyDbOperators.isLessThan:
        return v1 == v1;
      case TecfyDbOperators.islessThanOrEqualTo:
        return v1 == v1;

      case TecfyDbOperators.startwith:
      case TecfyDbOperators.endwith:
      case TecfyDbOperators.contains:
        return v1 == v1;

      default:
        return v1 == v1;
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
    for (var column in _columns[tableName] ?? []) {
      var type = (column.type as FieldTypes).name;
      if (type == FieldTypes.boolean.name) {
        var value = data[column.name] == true ? 1 : 0;
        result[column.name] = value;
      } else if (type == FieldTypes.datetime.name) {
        var value = data[column.name].millisecondsSinceEpoch;
        result[column.name] = value;
      } else {
        result[column.name] = data[column.name];
      }
    }

    if (result.isEmpty) {
      return null;
    } else {
      return result;
    }
  }

  Future<void> _checkPrimaryKeyChanged(String collectionName) async {
    var columnsSpecfs = (await dbColumnsSpecs(collectionName,
        removePrimarykeyAndJsonColumns: false));
    if (columnsSpecfs?.isEmpty ?? false) return;
    var dbPrimaryKey =
        columnsSpecfs?.firstWhere((element) => element.isPrimaryKey == true);

    TecfyIndexField? userPrimaryKey = _columns[collectionName]?.firstWhere(
        (element) => element?.isPrimaryKey == true,
        orElse: () => null);

    if ((dbPrimaryKey?.name == null && userPrimaryKey == null) ||
        (dbPrimaryKey?.name == 'id' && userPrimaryKey == null)) return;

    if (dbPrimaryKey?.name != userPrimaryKey?.name) {
      // drop table
      await _database?.rawQuery('drop table $collectionName');
    }
  }

  String _getCreationCollectionCommandAndOps(TecfyCollection element) {
    _columns[element.name] ??= [];

    String command = "CREATE TABLE IF NOT EXISTS ${element.name}(";
    bool tecfyIndexFieldsExisits = element.tecfyIndexFields != null &&
        (element.tecfyIndexFields?.isNotEmpty ?? false);
    if (element.primaryField != null) {
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

    // create indexes
    if (tecfyIndexFieldsExisits) {
      _indexs[element.name] = element.tecfyIndexFields ?? [];
      for (var singleIndexList in element.tecfyIndexFields!) {
        (_columns[element.name] as List).addAll(singleIndexList);
      }
    }
    return command;
  }

  Future<bool> isReadey() async {
    while (_database == null || _loading)
      await Future.delayed(Duration(milliseconds: 10));
    return true;
  }
}
