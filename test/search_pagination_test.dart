import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = TecfyDatabase(
      collections: [
        TecfyCollection('n', tecfyIndexFields: [
          [TecfyIndexField(name: 'v', type: FieldTypes.integer)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    for (var i = 1; i <= 10; i++) {
      await db.collection('n').add(data: {'v': i});
    }
  });
  tearDown(() async => db.dispose());

  test('searchCount counts matches', () async {
    final c = await db.collection('n').searchCount(
        filter: TecfyDbFilter('v', TecfyDbOperators.isGreaterThan, 5));
    expect(c, 5);
  });

  test('searchAny returns true when a match exists, false otherwise', () async {
    expect(
        await db.collection('n').searchAny(
            filter: TecfyDbFilter('v', TecfyDbOperators.isEqualTo, 3)),
        isTrue);
    expect(
        await db.collection('n').searchAny(
            filter: TecfyDbFilter('v', TecfyDbOperators.isEqualTo, 99)),
        isFalse);
  });

  test('limit + offset paginate ordered results', () async {
    final page =
        await db.collection('n').search(orderBy: 'v ASC', limit: 3, offset: 3);
    expect(page.map((e) => e['v']).toList(), [4, 5, 6]);
  });
}
