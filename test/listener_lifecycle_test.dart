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

  Map<String, dynamic> task(int i) =>
      {'title': 't$i', 'priority': i, 'isDone': false};

  test('streams that are never listened to register no listener', () async {
    final col = db.collection('tasks');
    for (var i = 0; i < 10; i++) {
      col.stream();
      col.count();
      col.doc(1).stream();
    }
    expect(col.listeners, isEmpty);
  });

  test('cancelling the last subscription unregisters the listener', () async {
    final col = db.collection('tasks');
    final subs = [
      col.stream().listen((_) {}),
      col.count().listen((_) {}),
      col.doc(1).stream().listen((_) {}),
    ];
    expect(col.listeners.length, 3);
    for (final s in subs) {
      await s.cancel();
    }
    expect(col.listeners, isEmpty);
  });

  test('a stream can be listened to again after cancel', () async {
    final col = db.collection('tasks');
    await col.add(data: task(1));
    final stream = col.stream();
    expect((await stream.first).length, 1);
    await col.add(data: task(2));
    expect((await stream.first).length, 2);
    expect(col.listeners, isEmpty);
  });

  test('a burst of notifications is coalesced and ends on the latest data',
      () async {
    final col = db.collection('tasks');
    final lengths = <int>[];
    final sub = col.stream().listen((rows) => lengths.add(rows.length));
    await Future.delayed(const Duration(milliseconds: 50));
    lengths.clear();

    for (var i = 0; i < 20; i++) {
      await col.add(data: task(i), notify: false);
    }
    for (var i = 0; i < 20; i++) {
      col.refreshListers();
    }
    await Future.delayed(const Duration(milliseconds: 100));

    // one query for the first call, one follow-up for the other 19
    expect(lengths, [20, 20]);
    await sub.cancel();
  });

  test('large result sets decode off-thread with the same shape', () async {
    final col = db.collection('tasks');
    final batch = col.getBatch();
    for (var i = 0; i < 1200; i++) {
      await col.add(data: task(i), batch: batch);
    }
    await col.commitBatch(batch: batch, notify: false);

    final rows = await col.search(orderBy: 'priority');
    expect(rows.length, 1200);
    expect(rows.first['id'], 1);
    expect(rows.first['title'], 't0');
    expect(rows.last['priority'], 1199);
  });

  test('a failed document write does not leave the lock held', () async {
    final col = db.collection('tasks');
    await col.add(data: task(1));
    await expectLater(col.doc(1).update(data: {'title': null, 'priority': 1}),
        throwsA(anything));
    expect(TecfyDatabase.dbLock, isFalse);
    expect((await col.doc(1).get())?['title'], 't1');
  });
}
