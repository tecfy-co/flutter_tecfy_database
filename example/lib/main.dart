// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:project/gallery/batch_page.dart';
import 'package:project/gallery/error_handling_page.dart';
import 'package:project/gallery/pagination_page.dart';
import 'package:project/gallery/queries_page.dart';
import 'package:project/gallery/streams_page.dart';
import 'package:project/roles_page.dart';
import 'package:project/users_page.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var db = TecfyDatabase(collections: [
    TecfyCollection('tasks', tecfyIndexFields: [
      [
        TecfyIndexField(name: "title", type: FieldTypes.text, nullable: false),
        TecfyIndexField(
          name: "desc",
          type: FieldTypes.integer,
        ),
      ],
      [TecfyIndexField(name: "isDone", type: FieldTypes.boolean, asc: false)],
      [
        TecfyIndexField(
            name: "createdAt", type: FieldTypes.datetime, asc: false)
      ],
    ]),
    TecfyCollection(
      'users',
      tecfyIndexFields: [
        [
          TecfyIndexField(name: "name", type: FieldTypes.text, nullable: false),
        ],
        [
          TecfyIndexField(
            name: "mobile",
            type: FieldTypes.integer,
          ),
        ],
        [
          TecfyIndexField(
              name: "createdAt", type: FieldTypes.datetime, asc: false)
        ],
      ],
    ),
    TecfyCollection('roles'),
    // Collections used by the advanced-usage gallery demos.
    TecfyCollection('demo', tecfyIndexFields: [
      [TecfyIndexField(name: "name", type: FieldTypes.text)],
      [TecfyIndexField(name: "age", type: FieldTypes.integer)],
      [TecfyIndexField(name: "city", type: FieldTypes.text)],
    ]),
    TecfyCollection('batchdemo', tecfyIndexFields: [
      [TecfyIndexField(name: "n", type: FieldTypes.integer)],
    ]),
    TecfyCollection('paging', tecfyIndexFields: [
      [TecfyIndexField(name: "n", type: FieldTypes.integer)],
    ]),
    TecfyCollection('streamdemo', tecfyIndexFields: [
      [TecfyIndexField(name: "label", type: FieldTypes.text)],
    ]),
    TecfyCollection(
      'uniq',
      primaryField: TecfyIndexField(name: "id", type: FieldTypes.integer),
      tecfyIndexFields: [
        [TecfyIndexField(name: "name", type: FieldTypes.text)],
      ],
    ),
  ]);
  await db.isReady();
  GetIt.I.registerSingleton<TecfyDatabase>(db, instanceName: 'db');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tecfy Database Gallery',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GalleryHomePage(),
    );
  }
}

/// Navigation-only home screen: a gallery of advanced-usage demos.
///
/// It intentionally does NOT touch the database while building, so the widget
/// renders immediately (and the smoke test can find its [ListTile]s). Each demo
/// page loads/seeds its own data in `initState`.
class GalleryHomePage extends StatelessWidget {
  const GalleryHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <_Demo>[
      _Demo(
        icon: Icons.person,
        title: 'Users',
        subtitle: 'Original CRUD + stream demo',
        builder: (_) => const UsersPage(),
      ),
      _Demo(
        icon: Icons.settings,
        title: 'Roles',
        subtitle: 'Original CRUD + stream demo (no indexes)',
        builder: (_) => const RolesPage(),
      ),
      _Demo(
        icon: Icons.search,
        title: 'Queries & filters',
        subtitle: 'isEqualTo, contains, nested AND/OR, arrayIn',
        builder: (_) => const QueriesPage(),
      ),
      _Demo(
        icon: Icons.bolt,
        title: 'Batch writes',
        subtitle: 'Batch vs. one-by-one inserts, timed',
        builder: (_) => const BatchPage(),
      ),
      _Demo(
        icon: Icons.view_list,
        title: 'Pagination',
        subtitle: 'limit / offset paging with Prev / Next',
        builder: (_) => const PaginationPage(),
      ),
      _Demo(
        icon: Icons.stream,
        title: 'Realtime streams',
        subtitle: 'Live list, live count, single-doc stream',
        builder: (_) => const StreamsPage(),
      ),
      _Demo(
        icon: Icons.error_outline,
        title: 'Error handling',
        subtitle: 'UNIQUE constraint + missing collection',
        builder: (_) => const ErrorHandlingPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tecfy Database Gallery'),
      ),
      body: ListView.separated(
        itemCount: demos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final demo = demos[index];
          return ListTile(
            leading: Icon(demo.icon),
            title: Text(demo.title),
            subtitle: Text(demo.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: demo.builder),
              );
            },
          );
        },
      ),
    );
  }
}

class _Demo {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  _Demo({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}
