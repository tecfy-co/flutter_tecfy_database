part of tecfy_database;

class TecfyCollectionOperations extends TecfyCollectionInterface {
  Database? _db;
  TecfyCollection collection;
  final Map<String, List<TecfyIndexField?>> _columns = {};
  final Map<String, List<TecfyIndexField>> _newcolumns = {};
  final Map<String, List<List<TecfyIndexField>>> _indexs = {};
  List<TecfyListener> listeners = [];

  Database? get database => _db;

  TecfyCollectionOperations(this.collection) {
    _initCollection();
  }

  @override
  Stream<List<Map<String, dynamic>>> stream(
      {ITecfyDbFilter? filter, String? orderBy}) {
    var listner = StreamController<List<Map<String, dynamic>>>.broadcast();
    var lis = TecfyListener(this, collection.name, listner,
        filter: filter, orderBy: orderBy);
    listeners.add(lis);
    lis.sendUpdate();
    // _sendListersUpdate(collectionName, null);
    return listner.stream;
  }

  void _initCollection() async {
    try {
      _db = GetIt.I.get<Database>(instanceName: 'tecfyDatabase');
      var createCommand = _getCreationCollectionCommandAndOps();
      await _checkPrimaryKeyChanged(collection.name);
      await _db?.execute(createCommand);
      await _updateColumnsAndIndexs(collection.name);
      // _loading = false;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _updateColumnsAndIndexs(String collectionName) async {
    var dbIndexesName = await _dbIndexesNames(collectionName);
    var newIndexesName = _getNewIndexesNames(collectionName);
    var dbColumns = await _dbColumnsSpecs(collectionName);
    if (_primaryKeyFieldName(collectionName) != 'id') {
      _columns[collectionName]?.removeWhere(
          (element) => element?.name == _primaryKeyFieldName(collectionName));
    }

    await _dropUnusedIndexes(dbIndexesName, newIndexesName);

    await _dropOldColumn(dbColumns);

    await _createNewColumn(dbColumns);
    await _createIndexes(dbIndexesName, newIndexesName);
    await _updatedNewColumnsValues();
  }

  Future<void> _updatedNewColumnsValues() async {
    if (_newcolumns.isEmpty ||
        (_newcolumns[collection.name]?.isEmpty ?? false)) {
      return;
    }

    var rowValues = await _db?.rawQuery('Select * from ${collection.name}');

    for (var rowValue in rowValues ?? []) {
      var value = (jsonDecode(rowValue['tecfy_json_body'] as String)
          as Map<String, dynamic>);

      var isUpdated = false;
      for (var newColumn in _newcolumns[collection.name]!) {
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
        // await updateDocument(
        //     collectionName: collection.name,
        //     data: rowValue,
        //     id: rowValue[_primaryKeyFieldName(collection.name)]);
      }
    }
  }

  Future<void> _dropUnusedIndexes(
      List<String> dbIndexesName, List<String> newIndexesName) async {
    try {
      if (newIndexesName.isEmpty) return;
      var unUsedIndexes = dbIndexesName
          .where((element) => !newIndexesName.contains(element))
          .toList();

      for (var unUsedIndexe in unUsedIndexes) {
        await _db?.rawQuery("DROP INDEX $unUsedIndexe");
      }
    } catch (e) {
      print(
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXException whild drop unused indexs ${e}');
    }
  }

  Future<void> _dropOldColumn(List<TecfyIndexField>? dbColumns) async {
    var columnsToBeRemovedList = dbColumns
        ?.where((element) => !(_columns[collection.name]!.contains(element)))
        .toList();

    if (columnsToBeRemovedList?.isEmpty ?? false) return;
    for (var columnToBeRemoved in columnsToBeRemovedList ?? []) {
      await _db?.rawQuery(
          'ALTER TABLE ${collection.name} DROP COLUMN ${columnToBeRemoved.name}');
    }
  }

  Future<void> _createNewColumn(
    List<TecfyIndexField>? dbColumns,
  ) async {
    var newColumnsToBeAddedList = _columns[collection.name]
        ?.where((element) => element?.isPrimaryKey == false)
        .toList()
        .where((element) => !(dbColumns?.contains(element) ?? false))
        .toList();

    if (newColumnsToBeAddedList?.isEmpty ?? false) return;
    for (var newColumn in newColumnsToBeAddedList!) {
      _newcolumns[collection.name] ??= [];
      _newcolumns[collection.name]?.add(newColumn!);
      await _db?.rawQuery(
          'ALTER TABLE ${collection.name} ADD COLUMN ${newColumn!.name} ${newColumn.type.name} ${newColumn.nullable ? "" : 'not null'}');
    }
  }

  Future<void> _createIndexes(
      List<String> dbIndexesName, List<String> newIndexesName) async {
    var indexedNeedToBeCreated = newIndexesName
        .where((element) => !dbIndexesName.contains(element))
        .toList();
    if (indexedNeedToBeCreated.isEmpty) return;
    for (var newIndex in (_indexs[collection.name] as List)) {
      var indName = _getIndexName(newIndex, collection.name);
      if (!indexedNeedToBeCreated.contains(indName)) continue;
      await _db?.rawQuery(
          "CREATE INDEX $indName ON ${collection.name} (${newIndex.map((e) => '${e.name}').join(',')});");
    }
  }

  List<String> _getNewIndexesNames(String tableName) {
    List<String> result = [];
    if (_indexs[tableName] == null) return [];
    for (var ind in (_indexs[tableName] as List)) {
      result.add(_getIndexName(ind, tableName));
    }
    return result;
  }

  String _getIndexName(List<TecfyIndexField> ind, String tableName) {
    var userIndexeNames = ind
        .map((e) => '${e.name}_${e.type.name}${e.asc ? '_a' : '_d'}')
        .toList();

    return 'idx_${tableName}_' + userIndexeNames.join('_');
  }

  Future<List<String>> _dbIndexesNames(String tableName) async {
    var result = (await _db?.rawQuery("PRAGMA index_list($tableName);"))
        ?.map((e) => e['name'].toString())
        .toList();

    result?.removeWhere((element) => !element.contains("idx_"));
    return result ?? [];
  }

  Future<List<TecfyIndexField>?> _dbColumnsSpecs(String tableName,
      {bool removePrimarykeyAndJsonColumns = true}) async {
    var dbColumns = (await _db?.rawQuery("PRAGMA table_info($tableName);"))
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

  int _primaryKeyIndex(String collectionName) => _columns[collectionName]!
      .indexWhere((element) => element?.isPrimaryKey == true);

  String _primaryKeyFieldName(String collectionName) =>
      _primaryKeyIndex(collectionName) == -1
          ? 'id'
          : _columns[collectionName]![_primaryKeyIndex(collectionName)]!.name;

  Future<void> _checkPrimaryKeyChanged(String collectionName) async {
    var columnsSpecfs = (await _dbColumnsSpecs(collectionName,
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
      await _db?.rawQuery('drop table $collectionName');
    }
  }

  String _getCreationCollectionCommandAndOps() {
    _columns[collection.name] ??= [];

    String command = "CREATE TABLE IF NOT EXISTS ${collection.name}(";
    bool tecfyIndexFieldsExisits = collection.tecfyIndexFields != null &&
        (collection.tecfyIndexFields?.isNotEmpty ?? false);
    if (collection.primaryField != null) {
      _columns[collection.name]
          ?.add(collection.primaryField!..isPrimaryKey = true);
      command +=
          "${collection.primaryField?.name} ${collection.primaryField?.type.name} primary key ${(collection.primaryField?.autoIncrement ?? false) ? "AUTOINCREMENT" : ""},";
    } else {
      command += "id integer primary key AUTOINCREMENT not null,";
    }

    List<String> indexKeies = [];

    if (tecfyIndexFieldsExisits) {
      for (var singleIndexList in collection.tecfyIndexFields!) {
        for (var singelIndexItem in singleIndexList) {
          if (!indexKeies.contains(singelIndexItem.name)) {
            command +=
                "${singelIndexItem.name} ${singelIndexItem.type.name} ${singelIndexItem.nullable ? "" : 'not null'},";
            indexKeies.add(singelIndexItem.name);
            // command += singleIndexList
            //         .map((e) =>
            //             "${e.name} ${e.type.name} ${e.nullable ? "" : 'not null'}")
            //         .join(',');
          }
          // command += ",";
        }
      }
    }
    command += "tecfy_json_body text);";

    // create indexes
    if (tecfyIndexFieldsExisits) {
      _indexs[collection.name] = collection.tecfyIndexFields ?? [];
      for (var singleIndexList in collection.tecfyIndexFields!) {
        (_columns[collection.name] as List).addAll(singleIndexList);
      }
    }
    return command;
  }

  @override
  Future<List<Map<String, dynamic>?>> get(
      {String? orderBy, String? groupBy}) async {
    try {
      var result = await _db?.query(collection.name,
              orderBy: orderBy, groupBy: groupBy) ??
          [];
      var data = _returnBody(collection.name, result);
      return data;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<bool> add(
      {required Map<String, dynamic> data,
      Object? Function(Object? p1)? toEncodableEx,
      String? nullColumnHack,
      ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      var body = _getInsertedBody(collection.name, data);
      var result = await _db?.insert(
        collection.name,
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

      if (result != 0) {
        _sendListersUpdate(collection.name, data);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void _sendListersUpdate(String collection, dynamic document) {
    listeners.removeWhere((l) => l.notifier.isClosed);
    listeners.where((l) {
      var filterCheckValue =
          document.isEmpty ? true : _filterCheck(document, filter: l.filter);
      return l.collectionName == collection && filterCheckValue;
    }).forEach((l) {
      l.sendUpdate();
    });
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
        var value = data[column.name];
        if (value != null) {
          if (value is DateTime) {
            value = value.microsecondsSinceEpoch;
          } else {
            value = value;
          }
        }
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

  @override
  Future<bool> exists(id) async {
    if (_db == null) throw Exception("Database Not Initlized!");
    var result = await _db!.query(collection.name,
        where: '${_primaryKeyFieldName(collection.name)} = ?',
        whereArgs: [id],
        limit: 1);

    return (result.isEmpty) ? false : true;
  }

  @override
  Stream<int> count({ITecfyDbFilter? filter}) {
    var listner = StreamController<int>.broadcast();
    var lis = TecfyListener(this, collection.name, listner, filter: filter);
    listeners.add(lis);
    lis.sendUpdateCount();
    // _sendListersUpdate(collectionName, null);
    return listner.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> search(
      {ITecfyDbFilter? filter,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    if (_db == null) throw Exception("Database Not Initlized!");
    List<dynamic> params = [];
    var sql;
    if (filter == null) {
      sql = null;
    } else {
      sql = _filterToString(filter, params);
    }
    var result = await _db!.query(
      collection.name,
      where: sql,
      whereArgs: params,
      groupBy: groupBy,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return _returnBody(collection.name, result);
  }

  String _filterToString(ITecfyDbFilter filter, List<dynamic> params) {
    if (filter.type == ITecfyDbFilterTypes.filter) {
      var f = filter as TecfyDbFilter;
      if (f.operator == TecfyDbOperators.startwith) {
        params.add('${f.value}%');
      } else if (f.operator == TecfyDbOperators.endwith) {
        params.add('%${f.value}');
      } else if (f.operator == TecfyDbOperators.isNull) {
      } else if (f.operator == TecfyDbOperators.contains) {
        params.add('%${f.value}%');
      } else {
        params.add(f.value);
      }
      if (f.operator == TecfyDbOperators.isNull) {
        return '${f.field} ${_getFilterOperatorValue(f.operator)} ${f.value == true ? '' : ' not'} null';
      } else {
        return '${f.field} ${_getFilterOperatorValue(f.operator)} ?';
      }
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
        var itemInCheckListCast = (itemInCheckList as TecfyIndexField);
        data = data.map((e) {
          var value = e[itemInCheckListCast.name];
          if (value != null) {
            e[itemInCheckListCast.name] =
                DateTime.fromMillisecondsSinceEpoch(value);
          }
          return e;
        }).toList();
      }
    }

    return data;
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
      case TecfyDbOperators.isNull:
        return 'is';

      case TecfyDbOperators.startwith:
      case TecfyDbOperators.endwith:
      case TecfyDbOperators.contains:
        return 'like';

      default:
        return '';
    }
  }

  bool _filterCheck(Map<String, dynamic> doc, {ITecfyDbFilter? filter}) {
    if (filter == null) return true;
    if (filter.type == ITecfyDbFilterTypes.filter) {
      var f = filter as TecfyDbFilter;
      var value = _filterOperatorValueCheck(f.operator, f.value, doc[f.field]);

      return value;
    } else {
      List<bool> ands = [];
      var f = filter.type == ITecfyDbFilterTypes.and
          ? (filter as TecfyDbAnd).filters
          : (filter as TecfyDbOr).filters;
      for (var filt in f) {
        ands.add(_filterCheck(doc, filter: filt));
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

  bool _filterOperatorValueCheck(
      TecfyDbOperators operator, dynamic v1, dynamic v2) {
    switch (operator) {
      case TecfyDbOperators.isEqualTo:
        return v2 == v1;

      case TecfyDbOperators.isNotEqualTo:
        return v2 != v1;

      case TecfyDbOperators.isGreaterThan:
        return v2 > v1;

      case TecfyDbOperators.isGreaterThanOrEqualTo:
        return v2 >= v1;

      case TecfyDbOperators.isLessThan:
        return v2 < v1;
      case TecfyDbOperators.islessThanOrEqualTo:
        return v2 <= v1;
      case TecfyDbOperators.startwith:
        return v2.toString().startsWith(v1);
      case TecfyDbOperators.endwith:
        return v2.toString().endsWith(v1);
      case TecfyDbOperators.contains:
        return v2.toString().contains(v1);
      default:
        return v2 == v1;
    }
  }

  @override
  TecfyDocumentOperations doc([id]) {
    return TecfyDocumentOperations(
      this,
      id,
    );
  }

  @override
  Future<bool> clear() async {
    try {
      await database?.execute("DELETE FROM ${collection.name}");
      return true;
    } catch (e) {
      debugPrint('error when delete collection');
      return false;
    }
  }
}
