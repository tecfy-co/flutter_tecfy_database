import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();

  test('custom text primary key is used for lookups and returned', () async {
    final db = newTestDb([
      TecfyCollection('users',
          primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
          tecfyIndexFields: [
            [TecfyIndexField(name: 'name', type: FieldTypes.text)],
          ]),
    ]);
    await db.isReady();

    expect(
        await db.collection('users').add(data: {'uid': 'u_1', 'name': 'Sara'}),
        isTrue);
    final doc = await db.collection('users').doc('u_1').get();
    expect(doc!['uid'], 'u_1');
    expect(doc['name'], 'Sara');
    await db.dispose();
  });

  test('default id primary key autoincrements', () async {
    final db = newTestDb([tasksCollection()]);
    await db.isReady();
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await col.add(data: {'title': 'b', 'priority': 1, 'isDone': false});
    final all = await col.get(orderBy: 'id ASC');
    expect(all.map((e) => e!['id']).toList(), [1, 2]);
    await db.dispose();
  });

  test('custom primary key is returned by get() read-back', () async {
    final db = newTestDb([
      TecfyCollection('users',
          primaryField: TecfyIndexField(name: 'uid', type: FieldTypes.text),
          tecfyIndexFields: [
            [TecfyIndexField(name: 'name', type: FieldTypes.text)],
          ]),
    ]);
    await db.isReady();
    await db.collection('users').add(data: {'uid': 'u_9', 'name': 'Zed'});
    final rows = await db.collection('users').get();
    expect(rows.length, 1);
    expect(rows.first!['uid'], 'u_9');
    expect(rows.first!['name'], 'Zed');
    await db.dispose();
  });
}
