import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

void main() {
  var db = TecfyDatabase(collections: [
    TecfyCollection('persons', TecfyIndexFields: [
      [
        TecfyIndexField(name: "job", type: FieldTypes.text, nullable: false),
        TecfyIndexField(name: "gender", type: FieldTypes.text, nullable: false),
      ],
      [TecfyIndexField(name: "age", type: FieldTypes.integer, asc: false)],
      [TecfyIndexField(name: "isActive", type: FieldTypes.boolean, asc: false)],
      [
        TecfyIndexField(
            name: "createdAt", type: FieldTypes.datetime, asc: false)
      ],
    ])
  ]);

  GetIt.I.registerSingleton<TecfyDatabase>(db, instanceName: 'db');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  var db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');

  void _incrementCounter({String functionName = 'search'}) async {
    switch (functionName) {
      case 'search':
        var result = await db.search(
            'persons',
            TecfyDbFilter('createdAtX', TecfyDbOperators.isEqualTo,
                DateTime.now().millisecondsSinceEpoch));
        print('=-=-=-=-=-=-=-=-=-${result}');
        break;
      case 'clearCollection':
        await db.clearCollection(
          collectionName: 'persons',
        );
        break;
      case 'insertDocument':
        var insertResult =
            await db.insertDocument(collectionName: 'persons', data: {
          "job": "driver",
          "gender": "male",
          "age": 33,
          "isActive": false,
          "createdAt": DateTime.now()
        });
        print('============> insert result ${insertResult}');
        break;
      case 'deleteDocument':
        var result = await db.deleteDocument(
            collectionName: 'persons', queryField: 'id', queryFieldValue: 1);
        print('=========>${result}');
        break;
      case 'updateDocument':
        var result3 = await db.updateDocument(collectionName: 'persons', data: {
          "role_no": 1,
          "job": "Tect2222 Updated",
          "gender": "male",
          "age": 22,
          "isActive": true,
          "createdAt": DateTime.now()
        });
        print('==-=-=-=-=-=-=-=${result3}');
        break;
      case 'getDocuments':
        var result2 = await db.getDocuments(
            collectionName: 'persons', orderBy: 'age desc');
        print('==-=-=-=-=-=-=-=${result2}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
