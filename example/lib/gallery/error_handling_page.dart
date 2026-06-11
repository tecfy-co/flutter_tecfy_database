import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

/// Shows the two ways Tecfy surfaces errors:
///  (a) `add` returns `false` (it does NOT throw) on a UNIQUE constraint —
///      inserting the same primary key twice on the `uniq` collection;
///  (b) `db.collection('does_not_exist')` throws, caught with try/catch.
class ErrorHandlingPage extends StatefulWidget {
  const ErrorHandlingPage({super.key});

  @override
  State<ErrorHandlingPage> createState() => _ErrorHandlingPageState();
}

class _ErrorHandlingPageState extends State<ErrorHandlingPage> {
  final db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  bool? _firstInsert;
  bool? _secondInsert;
  String? _caughtMessage;
  bool _ran = false;

  Future<void> _run() async {
    // (a) UNIQUE constraint: insert the same primary key id twice.
    final coll = db.collection('uniq');
    await coll.clear();
    final first = await coll.add(data: {'id': 1, 'name': 'first'});
    final second = await coll.add(data: {'id': 1, 'name': 'duplicate'});

    // (b) Missing collection throws — catch and surface the message.
    String? caught;
    try {
      db.collection('does_not_exist');
    } catch (e) {
      caught = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _firstInsert = first;
      _secondInsert = second;
      _caughtMessage = caught;
      _ran = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error handling')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _run,
              child: const Text('Run error demos'),
            ),
            const SizedBox(height: 24),
            if (_ran) ...[
              const Text(
                '(a) UNIQUE constraint on primary key id=1:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('first add()  → $_firstInsert  (inserted)'),
              Text('second add() → $_secondInsert  '
                  '(false = rejected, no throw)'),
              const SizedBox(height: 24),
              const Text(
                "(b) db.collection('does_not_exist') threw:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _caughtMessage ?? '(no exception?!)',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
