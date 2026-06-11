import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  TecfyDatabase typedDb() => TecfyDatabase(
        collections: [
          TecfyCollection('t', tecfyIndexFields: [
            [TecfyIndexField(name: 'i', type: FieldTypes.integer)],
            [TecfyIndexField(name: 'r', type: FieldTypes.real)],
            [TecfyIndexField(name: 's', type: FieldTypes.text)],
            [TecfyIndexField(name: 'b', type: FieldTypes.boolean)],
            [TecfyIndexField(name: 'd', type: FieldTypes.datetime)],
          ]),
        ],
        inMemory: true,
        databaseFactory: databaseFactoryFfi,
      );

  test('integer/real/text/boolean round-trip through add/get', () async {
    final db = typedDb();
    await db.isReady();
    await db.collection('t').add(data: {
      'i': 42,
      'r': 3.5,
      's': 'hello',
      'b': true,
      'd': DateTime.utc(2024, 1, 2, 3, 4, 5),
    });
    final doc = (await db.collection('t').get()).first!;
    expect(doc['i'], 42);
    expect(doc['r'], 3.5);
    expect(doc['s'], 'hello');
    expect(doc['b'], true);
    await db.dispose();
  });

  test('datetime round-trips back as a DateTime at millisecond precision',
      () async {
    final db = typedDb();
    await db.isReady();
    final when = DateTime.utc(2024, 6, 1, 12, 0, 0);
    await db.collection('t').add(data: {'d': when});
    final doc = (await db.collection('t').get()).first!;
    expect(doc['d'], isA<DateTime>());
    expect((doc['d'] as DateTime).millisecondsSinceEpoch,
        when.millisecondsSinceEpoch);
    await db.dispose();
  });
}
