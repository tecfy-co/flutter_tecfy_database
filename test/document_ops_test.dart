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

  test('doc(id).get returns the stored document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    final doc = await col.doc(1).get();
    expect(doc, isNotNull);
    expect(doc!['title'], 't');
  });

  test('doc(id).update replaces the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    final ok = await col.doc(1).update(
        data: {'title': 't2', 'priority': 5, 'isDone': true});
    expect(ok, isTrue);
    final doc = await col.doc(1).get();
    expect(doc!['title'], 't2');
    expect(doc['priority'], 5);
  });

  test('doc(id).delete removes the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    expect(await col.doc(1).delete(), isTrue);
    expect(await col.doc(1).get(), isNull);
  });

  test('exists reflects presence by primary key', () async {
    final col = db.collection('tasks');
    expect(await col.exists(1), isFalse);
    await col.add(data: {'title': 't', 'priority': 1, 'isDone': false});
    expect(await col.exists(1), isTrue);
  });

  test('update on a missing id returns false', () async {
    final col = db.collection('tasks');
    expect(
        await col.doc(999).update(
            data: {'title': 'x', 'priority': 1, 'isDone': false}),
        isFalse);
  });
}
