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

  test('collection stream emits initial data then updates on notifying add',
      () async {
    final col = db.collection('tasks');
    final lengths = <int>[];
    final sub = col.stream().listen((rows) => lengths.add(rows.length));
    await Future.delayed(const Duration(milliseconds: 50));

    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await Future.delayed(const Duration(milliseconds: 50));

    expect(lengths.first, 0);
    expect(lengths.last, 1);
    await sub.cancel();
  });

  test('count stream emits the live count', () async {
    final col = db.collection('tasks');
    final counts = <int>[];
    final sub = col.count().listen((c) => counts.add(c));
    await Future.delayed(const Duration(milliseconds: 50));
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    await Future.delayed(const Duration(milliseconds: 50));
    expect(counts.last, 1);
    await sub.cancel();
  });

  test('document stream emits the document', () async {
    final col = db.collection('tasks');
    await col.add(data: {'title': 'a', 'priority': 1, 'isDone': false});
    final doc = await col.doc(1).stream().first;
    expect(doc['title'], 'a');
  });
}
