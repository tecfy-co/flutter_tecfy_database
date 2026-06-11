import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = newTestDb([tasksCollection()]);
    await db.isReady();
  });
  tearDown(() async => db.dispose());

  test('document update via batch is applied only on commit', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final batch = col.getBatch();
    await col.doc(1).update(
        data: {'title': 'b', 'priority': 2, 'isDone': true}, batch: batch);
    expect((await col.doc(1).get())!['title'], 'a'); // not yet applied
    await col.commitBatch(batch: batch);
    expect((await col.doc(1).get())!['title'], 'b');
  });

  test('document delete via batch is applied only on commit', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final batch = col.getBatch();
    await col.doc(1).delete(batch: batch);
    expect(await col.doc(1).get(), isNotNull); // not yet applied
    await col.commitBatch(batch: batch);
    expect(await col.doc(1).get(), isNull);
  });

  test('update with notifier refreshes the document stream', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final titles = <String>[];
    final sub =
        col.doc(1).stream().listen((d) => titles.add(d['title'] as String));
    await Future.delayed(const Duration(milliseconds: 50));
    await col.doc(1).update(
        data: {'title': 'b', 'priority': 1, 'isDone': false}, notifier: true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(titles.last, 'b');
    await sub.cancel();
  });

  test('delete with notifier refreshes the collection stream', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final lengths = <int>[];
    final sub = col.stream().listen((rows) => lengths.add(rows.length));
    await Future.delayed(const Duration(milliseconds: 50));
    await col.doc(1).delete(notifier: true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(lengths.last, 0);
    await sub.cancel();
  });

  test('refreshListers forces a stream re-emit', () async {
    final col = db.collection('tasks');
    final lengths = <int>[];
    final sub = col.stream().listen((rows) => lengths.add(rows.length));
    await Future.delayed(const Duration(milliseconds: 50));
    col.refreshListers();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(lengths.length, greaterThanOrEqualTo(2));
    await sub.cancel();
  });

  test('clearDb empties every collection', () async {
    await db
        .collection('tasks')
        .add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await db.clearDb();
    expect((await db.collection('tasks').get()).isEmpty, isTrue);
  });

  test('model toJson serializes collection and index-field metadata', () async {
    final field = TecfyIndexField(name: 'x', type: FieldTypes.text);
    final json = field.toJson();
    expect(json['name'], 'x');
    expect(json['type'], 'text');

    final coll = TecfyCollection('c', tecfyIndexFields: [
      [field]
    ]);
    final cjson = coll.toJson();
    expect(cjson['name'], 'c');
  });
}
