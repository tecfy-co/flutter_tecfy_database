import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();

  test('add returns false on a UNIQUE constraint violation', () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('u',
            primaryField: TecfyIndexField(name: 'id', type: FieldTypes.integer),
            tecfyIndexFields: [
              [TecfyIndexField(name: 'name', type: FieldTypes.text)],
            ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    expect(await db.collection('u').add(data: {'id': 1, 'name': 'a'}), isTrue);
    expect(await db.collection('u').add(data: {'id': 1, 'name': 'b'}), isFalse);
    await db.dispose();
  });

  test('doc.get returns null for empty/blank id', () async {
    final db = TecfyDatabase(
      collections: [
        TecfyCollection('c', tecfyIndexFields: [
          [TecfyIndexField(name: 'a', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    expect(await db.collection('c').doc('').get(), isNull);
    await db.dispose();
  });
}
