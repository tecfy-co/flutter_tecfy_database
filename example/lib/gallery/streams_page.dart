import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

/// Realtime demo on the `streamdemo` collection:
///  - a `StreamBuilder<List<...>>` over `collection.stream(orderBy: ...)`,
///  - a `StreamBuilder<int>` over `collection.count()`,
///  - a `doc(id).stream()` for a single tracked document.
///
/// Add/Delete use `notify: true` / `notifier: true` so every stream updates
/// live without a manual refresh.
class StreamsPage extends StatefulWidget {
  const StreamsPage({super.key});

  @override
  State<StreamsPage> createState() => _StreamsPageState();
}

class _StreamsPageState extends State<StreamsPage> {
  final db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  dynamic _trackedId;
  bool _ready = false;

  TecfyCollectionOperations get _coll => db.collection('streamdemo');

  @override
  void initState() {
    super.initState();
    _ensureTrackedDoc();
  }

  Future<void> _ensureTrackedDoc() async {
    // Make sure at least one row exists, and remember its id for doc.stream().
    var rows = await _coll.search(orderBy: 'label ASC', limit: 1);
    if (rows.isEmpty) {
      await _coll.add(data: {'label': 'Tracked item'}, notify: true);
      rows = await _coll.search(orderBy: 'label ASC', limit: 1);
    }
    if (!mounted) return;
    setState(() {
      _trackedId = rows.isNotEmpty ? rows.first['id'] : null;
      _ready = true;
    });
  }

  Future<void> _add() async {
    await _coll.add(
      data: {'label': 'Item ${DateTime.now().millisecondsSinceEpoch}'},
      notify: true,
    );
  }

  Future<void> _delete(dynamic id) async {
    await _coll.doc(id.toString()).delete(notifier: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime streams')),
      body: Column(
        children: [
          // Live count via count() stream.
          StreamBuilder<int>(
            stream: _coll.count(),
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Live count: ${snapshot.data ?? 0}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          // Single-document stream.
          if (_ready && _trackedId != null)
            StreamBuilder<Map<String, dynamic>>(
              stream: _coll.doc(_trackedId).stream(),
              builder: (context, snapshot) {
                final label = snapshot.data?['label'] ?? '(deleted)';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Tracked doc #$_trackedId: $label'),
                );
              },
            ),
          const Divider(),
          // Live list via stream().
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _coll.stream(orderBy: 'label ASC'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('No data — tap +'));
                }
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final row = data[index];
                    return ListTile(
                      title: Text('${row['label']}'),
                      subtitle: Text('id: ${row['id']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _delete(row['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'add item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
