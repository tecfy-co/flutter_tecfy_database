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

  test('batched adds commit together', () async {
    final col = db.collection('tasks');
    final batch = col.getBatch();
    for (var i = 0; i < 5; i++) {
      await col.add(
          data: {'title': 't$i', 'priority': i, 'isDone': false},
          batch: batch);
    }
    expect((await col.get()).isEmpty, isTrue);

    await col.commitBatch(batch: batch);
    expect((await col.get()).length, 5);
  });

  test('commitBatch fires a single stream notification', () async {
    final col = db.collection('tasks');
    final emissions = <int>[];
    final sub = col.count().listen((c) => emissions.add(c));
    await Future.delayed(const Duration(milliseconds: 50));

    final batch = col.getBatch();
    for (var i = 0; i < 3; i++) {
      await col.add(
          data: {'title': 't$i', 'priority': i, 'isDone': false},
          batch: batch);
    }
    await col.commitBatch(batch: batch, notify: true);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(emissions.last, 3);
    await sub.cancel();
  });
}
