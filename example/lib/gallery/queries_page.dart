import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

/// Demonstrates the query/filter API on the indexed `demo` collection:
/// simple equality, a LIKE `contains`, a nested AND/OR, and an `arrayIn`.
///
/// Only indexed fields (here: name, age, city) can be filtered/sorted/grouped.
class QueriesPage extends StatefulWidget {
  const QueriesPage({super.key});

  @override
  State<QueriesPage> createState() => _QueriesPageState();
}

class _QueriesPageState extends State<QueriesPage> {
  final db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  bool _loading = true;
  final List<_QueryResult> _results = [];

  @override
  void initState() {
    super.initState();
    _seedAndRun();
  }

  Future<void> _seedAndRun() async {
    final demo = db.collection('demo');

    // Seed a few rows once.
    final existing = await demo.searchCount();
    if ((existing ?? 0) == 0) {
      final seed = <Map<String, dynamic>>[
        {'name': 'Alice', 'age': 30, 'city': 'Cairo'},
        {'name': 'Bob', 'age': 25, 'city': 'Cairo'},
        {'name': 'Carol', 'age': 40, 'city': 'Giza'},
        {'name': 'Dave', 'age': 22, 'city': 'Alexandria'},
        {'name': 'Eve', 'age': 35, 'city': 'Giza'},
      ];
      for (final row in seed) {
        await demo.add(data: row, notify: false);
      }
    }

    // 1) Simple equality on an indexed field.
    final eq = await demo.search(
      filter: TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Cairo'),
      orderBy: 'name ASC',
    );

    // 2) LIKE `contains` on a text field.
    final like = await demo.search(
      filter: TecfyDbFilter('name', TecfyDbOperators.contains, 'a'),
      orderBy: 'name ASC',
    );

    // 3) Nested AND/OR: (city = Giza) AND (age > 30 OR name = Carol).
    final nested = await demo.search(
      filter: TecfyDbAnd([
        TecfyDbFilter('city', TecfyDbOperators.isEqualTo, 'Giza'),
        TecfyDbOr([
          TecfyDbFilter('age', TecfyDbOperators.isGreaterThan, 30),
          TecfyDbFilter('name', TecfyDbOperators.isEqualTo, 'Carol'),
        ]),
      ]),
      orderBy: 'name ASC',
    );

    // 4) arrayIn: city in (Cairo, Alexandria).
    final inList = await demo.search(
      filter: TecfyDbFilter(
        'city',
        TecfyDbOperators.arrayIn,
        ['Cairo', 'Alexandria'],
      ),
      orderBy: 'name ASC',
    );

    if (!mounted) return;
    setState(() {
      _results
        ..clear()
        ..addAll([
          _QueryResult("city isEqualTo 'Cairo'", eq),
          _QueryResult("name contains 'a' (LIKE)", like),
          _QueryResult(
            'city = Giza AND (age > 30 OR name = Carol)',
            nested,
          ),
          _QueryResult("city arrayIn ['Cairo','Alexandria']", inList),
        ]);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queries & filters')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                const Card(
                  color: Color(0xFFFFF3E0),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Note: only indexed fields are queryable. '
                      'Here name, age and city are indexed.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                for (final r in _results) _buildResult(r),
              ],
            ),
    );
  }

  Widget _buildResult(_QueryResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.description,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text('${r.rows.length} row(s)'),
            const SizedBox(height: 4),
            if (r.rows.isEmpty)
              const Text('— no matches —')
            else
              ...r.rows.map(
                (row) => Text(
                  "• ${row['name']}  (age ${row['age']}, ${row['city']})",
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueryResult {
  final String description;
  final List<Map<String, dynamic>> rows;
  _QueryResult(this.description, this.rows);
}
