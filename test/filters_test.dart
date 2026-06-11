import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  sqfliteFfiInit();
  late TecfyDatabase db;

  setUp(() async {
    db = TecfyDatabase(
      collections: [
        TecfyCollection('p', tecfyIndexFields: [
          [TecfyIndexField(name: 'name', type: FieldTypes.text)],
          [TecfyIndexField(name: 'age', type: FieldTypes.integer)],
          [TecfyIndexField(name: 'city', type: FieldTypes.text)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    final col = db.collection('p');
    await col.add(data: {'name': 'Ann', 'age': 30, 'city': 'Cairo'});
    await col.add(data: {'name': 'Bob', 'age': 25, 'city': 'Giza'});
    await col.add(data: {'name': 'Cara', 'age': 40, 'city': 'Cairo'});
  });
  tearDown(() async => db.dispose());

  Future<List<Map<String, dynamic>>> find(ITecfyDbFilter f) =>
      db.collection('p').search(filter: f);

  test('isEqualTo', () async {
    final r =
        await find(TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Cairo'));
    expect(r.length, 2);
  });
  test('isNotEqualTo', () async {
    final r = await find(
        TecfyDbFilter('city', TecfyDbOperators.isNotEqualTo, 'Cairo'));
    expect(r.length, 1);
  });
  test('isGreaterThan / isLessThan', () async {
    expect(
        (await find(TecfyDbFilter('age', TecfyDbOperators.isGreaterThan, 30)))
            .length,
        1);
    expect(
        (await find(TecfyDbFilter('age', TecfyDbOperators.isLessThan, 30)))
            .length,
        1);
  });
  test('isGreaterThanOrEqualTo / isLessThanOrEqualTo', () async {
    expect(
        (await find(TecfyDbFilter(
                'age', TecfyDbOperators.isGreaterThanOrEqualTo, 30)))
            .length,
        2);
    expect(
        (await find(
                TecfyDbFilter('age', TecfyDbOperators.isLessThanOrEqualTo, 30)))
            .length,
        2);
  });
  test('startWith / endWith / contains', () async {
    expect(
        (await find(TecfyDbFilter('name', TecfyDbOperators.startWith, 'A')))
            .length,
        1);
    expect(
        (await find(TecfyDbFilter('name', TecfyDbOperators.endWith, 'b')))
            .length,
        1);
    expect(
        (await find(TecfyDbFilter('name', TecfyDbOperators.contains, 'ar')))
            .length,
        1);
  });
  test('arrayIn', () async {
    final r = await find(
        TecfyDbFilter('city', TecfyDbOperators.arrayIn, ['Giza', 'Cairo']));
    expect(r.length, 3);
  });
  test('isNull (false = is not null)', () async {
    final r = await find(TecfyDbFilter('city', TecfyDbOperators.isNull, false));
    expect(r.length, 3);
  });
  test('nested AND / OR', () async {
    final r = await find(TecfyDbOr([
      TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Giza'),
      TecfyDbAnd([
        TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Cairo'),
        TecfyDbFilter('age', TecfyDbOperators.isGreaterThan, 35),
      ]),
    ]));
    expect(r.map((e) => e['name']).toSet(), {'Bob', 'Cara'});
  });
}
