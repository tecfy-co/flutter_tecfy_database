import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();

  test('isReady resolves true for a fresh in-memory db', () async {
    final db = newTestDb([tasksCollection()]);
    expect(await db.isReady(), isTrue);
    await db.dispose();
  });

  test('collection() throws for an unknown collection', () async {
    final db = newTestDb([tasksCollection()]);
    await db.isReady();
    expect(() => db.collection('nope'), throwsException);
    await db.dispose();
  });

  test('can re-init a new database after dispose', () async {
    final db1 = newTestDb([tasksCollection()]);
    await db1.isReady();
    await db1.dispose();

    final db2 = newTestDb([tasksCollection()]);
    expect(await db2.isReady(), isTrue);
    expect(await db2.collection('tasks').add(data: {'title': 'x'}), isTrue);
    await db2.dispose();
  });
}
