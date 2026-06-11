import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

/// Compares inserting 100 docs via a single atomic [Batch] vs. 100 sequential
/// `await add(...)` calls, timing each so the speed difference is visible.
///
/// Tecfy exposes `Batch` (getBatch / commitBatch) for atomic, single-
/// notification writes; there is no separate `transaction()` API.
class BatchPage extends StatefulWidget {
  const BatchPage({super.key});

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  static const int _count = 100;

  bool _running = false;
  Duration? _batchTime;
  Duration? _sequentialTime;

  Future<void> _runBatch() async {
    setState(() => _running = true);
    final coll = db.collection('batchdemo');
    await coll.clear();

    final sw = Stopwatch()..start();
    final batch = coll.getBatch();
    for (var i = 0; i < _count; i++) {
      // Queue each insert onto the batch (no write yet).
      await coll.add(data: {'n': i, 'note': 'batch row $i'}, batch: batch);
    }
    await coll.commitBatch(batch: batch, notify: true);
    sw.stop();

    if (!mounted) return;
    setState(() {
      _batchTime = sw.elapsed;
      _running = false;
    });
  }

  Future<void> _runSequential() async {
    setState(() => _running = true);
    final coll = db.collection('batchdemo');
    await coll.clear();

    final sw = Stopwatch()..start();
    for (var i = 0; i < _count; i++) {
      // Each await is its own transaction + listener notification.
      await coll.add(data: {'n': i, 'note': 'seq row $i'}, notify: false);
    }
    sw.stop();

    if (!mounted) return;
    setState(() {
      _sequentialTime = sw.elapsed;
      _running = false;
    });
  }

  String _fmt(Duration? d) =>
      d == null ? '—' : '${d.inMilliseconds} ms (${d.inMicroseconds} µs)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch writes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Color(0xFFFFF3E0),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tecfy exposes `Batch` for atomic, single-notification '
                  'writes. There is no separate transaction() API — use a '
                  'batch.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _running ? null : _runBatch,
              child: Text('Insert $_count docs with a Batch'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _running ? null : _runSequential,
              child: Text('Insert $_count docs one-by-one'),
            ),
            const SizedBox(height: 24),
            if (_running) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text('Batch:        ${_fmt(_batchTime)}'),
            const SizedBox(height: 8),
            Text('One-by-one:   ${_fmt(_sequentialTime)}'),
            const SizedBox(height: 16),
            if (_batchTime != null && _sequentialTime != null)
              Text(
                _sequentialTime!.inMicroseconds == 0
                    ? ''
                    : 'Batch was '
                        '${(_sequentialTime!.inMicroseconds / (_batchTime!.inMicroseconds == 0 ? 1 : _batchTime!.inMicroseconds)).toStringAsFixed(1)}x '
                        'faster.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
