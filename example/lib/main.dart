import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() async {
  var db = TecfyDatabase(collections: [
    TecfyCollection('tasks',
        // primaryField: TecfyIndexField(
        //     name: "roll_no",
        //     type: FieldTypes.integer,
        //     nullable: false,
        //     autoIncrement: true),
        tecfyIndexFields: [
          [
            TecfyIndexField(
                name: "title", type: FieldTypes.text, nullable: false),
            TecfyIndexField(
              name: "desc",
              type: FieldTypes.integer,
            ),
          ],
          [
            TecfyIndexField(
                name: "isDone", type: FieldTypes.boolean, asc: false)
          ],
          [
            TecfyIndexField(
                name: "createdAt", type: FieldTypes.datetime, asc: false)
          ],
        ])
  ]);
  await db.isReadey();
  GetIt.I.registerSingleton<TecfyDatabase>(db, instanceName: 'db');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');
  final TextEditingController _titleFieldController = TextEditingController();
  final TextEditingController _descFieldController = TextEditingController();

  // void _incrementCounter({String functionName = 'xx'}) async {
  //   db.dbColumnsSpecs('persons');
  //   // db.updateColumnsAndIndexs('persons');
  //   // db.clearCollection(collectionName: 'persons');
  //   switch (functionName) {
  //     case 'search':
  //       var result = await db.search(
  //           'persons',
  //           TecfyDbFilter('createdAtX', TecfyDbOperators.isEqualTo,
  //               DateTime.now().millisecondsSinceEpoch));
  //       print('=-=-=-=-=-=-=-=-=-${result}');
  //       break;
  //     case 'clearCollection':
  //       await db.clearCollection(
  //         collectionName: 'persons',
  //       );
  //       break;
  //     case 'insertDocument':
  //       var insertResult =
  //           await db.insertDocument(collectionName: 'persons', data: {
  //         "job": "driver",
  //         "gender": "male",
  //         "age": 33,
  //         "isActive": false,
  //         "createdAt": DateTime.now()
  //       });
  //       print('============> insert result ${insertResult}');
  //       break;
  //     case 'deleteDocument':
  //       var result = await db.deleteDocument(
  //           collectionName: 'persons', queryField: 'id', queryFieldValue: 1);
  //       print('=========>${result}');
  //       break;
  //     case 'updateDocument':
  //       var result3 = await db.updateDocument(collectionName: 'persons', data: {
  //         "role_no": 1,
  //         "job": "Tect2222 Updated",
  //         "gender": "male",
  //         "age": 22,
  //         "isActive": true,
  //         "createdAt": DateTime.now()
  //       });
  //       print('==-=-=-=-=-=-=-=${result3}');
  //       break;
  //     case 'getDocuments':
  //       var result2 = await db.getDocuments(
  //           collectionName: 'persons', orderBy: 'age desc');
  //       print('==-=-=-=-=-=-=-=${result2}');
  //       break;
  //   }
  // }

  Future<void> _displayDialog() async {
    var result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add a task to your list'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: TextField(
                    controller: _titleFieldController,
                    decoration: const InputDecoration(hintText: 'title'),
                  ),
                ),
                TextField(
                  controller: _descFieldController,
                  decoration: const InputDecoration(hintText: 'desc'),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('ADD'),
                onPressed: () async {
                  var insertResult =
                      await db.insertDocument(collectionName: 'tasks', data: {
                    "title": _titleFieldController.text,
                    "desc": _descFieldController.text,
                    "isDone": false,
                    "createdAt": DateTime.now()
                  });
                  print('============> insert result ${insertResult}');

                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('CANCEL'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });

    if (result != null) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo App'),
      ),
      body: StreamBuilder(
          stream: db.searchListner(
              'tasks', TecfyDbFilter('title', TecfyDbOperators.startwith, 'a')),
          builder: (context, snapshot) {
            print('=============> ${snapshot.data}');
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.data?.isEmpty ?? false) {
              return Center(
                child: Text(
                  "No Data found",
                ),
              );
            } else {
              return ListView.builder(
                  itemCount: snapshot.data?.length,
                  itemBuilder: (context, index) => ListTile(
                        leading: Text(snapshot.data?[index]['title']),
                      ));
            }
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _displayDialog(),
        tooltip: 'add new todo',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
