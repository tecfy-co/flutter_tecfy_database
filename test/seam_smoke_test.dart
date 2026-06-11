import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  test('opens an in-memory database via the factory seam and is ready',
      () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('items', tecfyIndexFields: [
          [TecfyIndexField(name: 'name', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );

    expect(await db.isReady(), isTrue);

    final ok = await db.collection('items').add(data: {'name': 'a'});
    expect(ok, isTrue);
    expect((await db.collection('items').get()).length, 1);

    await db.dispose();
  });
}
