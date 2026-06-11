import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('tecfy_mig'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  TecfyDatabase open(List<TecfyCollection> cols) => TecfyDatabase(
        collections: cols,
        dbName: '${tmp.path}${Platform.pathSeparator}mig.db',
        databaseFactory: databaseFactoryFfi,
      );

  test('adding a new index field adds its column and keeps existing data',
      () async {
    var db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    await db.collection('c').add(data: {'a': 'x', 'b': 'y'});
    await db.dispose();

    db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
        [TecfyIndexField(name: 'b', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    final docs = await db.collection('c').get();
    expect(docs.length, 1);
    expect(docs.first!['a'], 'x');
    expect(docs.first!['b'], 'y');
    await db.dispose();
  });

  test('changing the primary key drops and recreates the table', () async {
    var db = open([
      TecfyCollection('c', tecfyIndexFields: [
        [TecfyIndexField(name: 'a', type: FieldTypes.text)],
      ]),
    ]);
    await db.isReady();
    await db.collection('c').add(data: {'a': 'x'});
    await db.dispose();

    db = open([
      TecfyCollection('c',
          primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
          tecfyIndexFields: [
            [TecfyIndexField(name: 'a', type: FieldTypes.text)],
          ]),
    ]);
    await db.isReady();
    expect((await db.collection('c').get()).isEmpty, isTrue);
    await db.dispose();
  });
}
