import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

/// Pages through ~50 rows of the indexed `paging` collection using
/// `search(orderBy: 'n ASC', limit: pageSize, offset: page * pageSize)`.
class PaginationPage extends StatefulWidget {
  const PaginationPage({super.key});

  @override
  State<PaginationPage> createState() => _PaginationPageState();
}

class _PaginationPageState extends State<PaginationPage> {
  final db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  static const int _pageSize = 10;
  static const int _total = 50;

  int _page = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _seedThenLoad();
  }

  Future<void> _seedThenLoad() async {
    final coll = db.collection('paging');
    final count = await coll.searchCount() ?? 0;
    if (count < _total) {
      await coll.clear();
      final batch = coll.getBatch();
      for (var i = 0; i < _total; i++) {
        await coll.add(data: {'n': i, 'label': 'Item #$i'}, batch: batch);
      }
      await coll.commitBatch(batch: batch, notify: false);
    }
    await _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    final coll = db.collection('paging');
    final rows = await coll.search(
      orderBy: 'n ASC',
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  int get _pageCount => (_total / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagination')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Page ${_page + 1} of $_pageCount  '
              '(limit $_pageSize, offset ${_page * _pageSize})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${row['n']}')),
                        title: Text('${row['label']}'),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _page > 0
                        ? () {
                            setState(() => _page--);
                            _loadPage();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Prev'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _page < _pageCount - 1
                        ? () {
                            setState(() => _page++);
                            _loadPage();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
