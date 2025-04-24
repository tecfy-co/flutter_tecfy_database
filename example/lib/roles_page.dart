// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tecfy_database/tecfy_database.dart';

class RolesPage extends StatefulWidget {
  const RolesPage({super.key});

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  var db = GetIt.I.get<TecfyDatabase>(instanceName: 'db');
  final TextEditingController _nameFieldController = TextEditingController();

  Future<void> _displayDialog(value) async {
    if (value != null) {
      _nameFieldController.text = value['name'];
    }
    var result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add a role to your list'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: TextField(
                    controller: _nameFieldController,
                    decoration: const InputDecoration(hintText: 'name'),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: value != null
                    ? () async {
                        await db.collection('roles').doc(value['id']).update(
                            data: {
                              "name": _nameFieldController.text,
                              "isDone": true,
                              "createdAt": DateTime.now()
                            },
                            notifier: true);
                        Navigator.of(context).pop();
                      }
                    : () async {
                        await db.collection('roles').add(data: {
                          "name": _nameFieldController.text,
                          "createdAt": DateTime.now()
                        });

                        Navigator.of(context).pop();
                      },
                child: Text(value != null ? "Update" : 'ADD'),
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
        title: const Text('Roles Page'),
      ),
      body: Row(
        children: [
          Expanded(
            child: StreamBuilder(
                stream: db.collection('roles').stream(),
                builder: (context, snapshot) {
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
                            onTap: () => onUpdateClicked(snapshot.data?[index]),
                            trailing: trailingWidget(snapshot.data?[index]),
                            leading: Text(snapshot.data?[index]['name'])));
                  }
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _displayDialog(null),
        tooltip: 'add new user',
        child: const Icon(Icons.add),
      ),
    );
  }

  void onUpdateClicked(value) {
    _displayDialog(value);
  }

  Widget trailingWidget(value) {
    return IconButton(
        onPressed: () async {
          await db.collection('roles').doc(value['id'].toString()).delete();
        },
        icon: Icon(Icons.delete));
  }
}
