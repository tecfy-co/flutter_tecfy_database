// tecfy_database benchmark harness.
//
// Run with:  fvm flutter test benchmark/tecfy_benchmark.dart
//
// Uses an in-memory FFI database for reproducibility. Results print to the
// test console. Numbers are indicative and vary with hardware/platform.
import 'package:flutter_test/flutter_test.dart';
import 'package:tecfy_database/tecfy_database.dart';

Future<int> _time(Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  await body();
  sw.stop();
  return sw.elapsedMilliseconds;
}

void main() {
  sqfliteFfiInit();

  test('tecfy_database benchmark', () async {
    const n = 5000; // rows inserted
    const queries = 1000; // indexed point queries / updates / deletes
    const scans = 200; // full-scan lookups (no-index equivalent)

    final db = TecfyDatabase(
      collections: [
        TecfyCollection('bench', tecfyIndexFields: [
          [TecfyIndexField(name: 'k', type: FieldTypes.integer)],
        ]),
      ],
      inMemory: true,
      databaseFactory: databaseFactoryFfi,
    );
    await db.isReady();
    final col = db.collection('bench');

    // Bulk insert via a single batch.
    final insertMs = await _time(() async {
      final batch = col.getBatch();
      for (var i = 0; i < n; i++) {
        await col.add(data: {'k': i, 'payload': 'row $i'}, batch: batch);
      }
      await col.commitBatch(batch: batch, notify: false);
    });

    // Indexed point queries — backed by the B-tree index on `k`.
    final indexedMs = await _time(() async {
      for (var i = 0; i < queries; i++) {
        await col.search(
            filter: TecfyDbFilter('k', TecfyDbOperators.isEqualTo, i % n));
      }
    });

    // No-index equivalent: fetch all rows and filter in Dart (full scan).
    // Non-indexed fields aren't directly queryable, so a full scan + in-app
    // filter is the alternative cost.
    final scanMs = await _time(() async {
      for (var i = 0; i < scans; i++) {
        final all = await col.get();
        all.firstWhere((r) => r!['k'] == i % n,
            orElse: () => <String, dynamic>{});
      }
    });

    // Update by primary key.
    final updateMs = await _time(() async {
      for (var i = 0; i < queries; i++) {
        await col.doc((i % n) + 1).update(data: {'k': i % n, 'payload': 'u$i'});
      }
    });

    // Delete by primary key (first `queries` rows).
    final deleteMs = await _time(() async {
      for (var i = 1; i <= queries; i++) {
        await col.doc(i).delete();
      }
    });

    String per(int ms, int count) => (ms / count).toStringAsFixed(3);
    // ignore: avoid_print
    print('--- tecfy_database benchmark (in-memory FFI) ---');
    // ignore: avoid_print
    print(
        'Batch insert $n docs:            $insertMs ms (${per(insertMs, n)} ms/doc)');
    // ignore: avoid_print
    print(
        'Indexed point query x$queries:   $indexedMs ms (${per(indexedMs, queries)} ms/query)');
    // ignore: avoid_print
    print(
        'Full-scan lookup x$scans:        $scanMs ms (${per(scanMs, scans)} ms/lookup)');
    // ignore: avoid_print
    print(
        'Update x$queries:                $updateMs ms (${per(updateMs, queries)} ms/op)');
    // ignore: avoid_print
    print(
        'Delete x$queries:                $deleteMs ms (${per(deleteMs, queries)} ms/op)');

    await db.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
