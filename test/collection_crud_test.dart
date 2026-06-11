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

  test('add returns true and assigns an autoincrement id', () async {
    final ok = await db.collection('tasks').add(data: {
      'title': 'first',
      'priority': 1,
      'isDone': false,
      'notes': {'nested': true},
    });
    expect(ok, isTrue);

    final all = await db.collection('tasks').get();
    expect(all.length, 1);
    expect(all.first!['id'], 1);
    expect(all.first!['title'], 'first');
    expect(all.first!['notes'], {'nested': true});
  });

  test('get returns all docs ordered by an indexed column', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'b', 'priority': 2, 'isDone': false});
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final ordered = await col.get(orderBy: 'priority ASC');
    expect(ordered.map((e) => e!['title']).toList(), ['a', 'b']);
  });

  test('clear deletes all docs but keeps the table', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'x', 'priority': 1, 'isDone': false});
    expect(await col.clear(), isTrue);
    expect((await col.get()).isEmpty, isTrue);
    expect(await col.add(data: {'title': 'y', 'priority': 1, 'isDone': false}),
        isTrue);
  });
}
