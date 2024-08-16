import 'plan_route.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';

class PlanLoadSaveWidget extends StatefulWidget {
  const PlanLoadSaveWidget({super.key});


  @override
  State<StatefulWidget> createState() => PlanLoadSaveWidgetState();
}


class PlanLoadSaveWidgetState extends State<PlanLoadSaveWidget> {

  String _name = "";
  List<String> _currentItems = [];


  void _saveRoute(PlanRoute route) {
    Storage().realmHelper.addPlan(_name, route);
    setState(() {
      Storage().route.name = _name;
      _currentItems.insert(0, Storage().route.name);
    });
  }

  Widget _makeContent() {
    _name = Storage().route.name;

    return Container(padding: const EdgeInsets.all(0),
          child: Column(children: [
            Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0), child: const Text("Load & Save", style: TextStyle(fontWeight: FontWeight.w800),),)),
            Expanded(
                flex: 3,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    child: Row(
                        children: [
                          Expanded(
                              flex: 5,
                              child: TextFormField(
                                  initialValue: _name ,
                                  onChanged: (value)  {
                                    _name = value;
                                  },
                                  decoration: const InputDecoration(border: UnderlineInputBorder(), labelText: 'Plan Name',)
                              )
                          ),
                          const Padding(padding: EdgeInsets.all(10)),
                          Expanded(
                              flex: 2,
                              child: TextButton(
                                  onPressed: () {
                                    _saveRoute(Storage().route);
                                  },
                                  child: const Text("Save")
                              )
                          )
                        ]
                    )
                )
            ),
            Expanded(
                flex: 10,
                child: ListView.builder(
                  itemCount: _currentItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_currentItems[index].toString()),
                      trailing: PopupMenuButton(
                        tooltip: "",
                        itemBuilder: (BuildContext context)  => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            child: const Text('Load'),
                            onTap: () {
                              Storage().realmHelper.getPlan(_currentItems[index], false).then((value) {
                                Storage().route.copyFrom(value);
                                Storage().route.setCurrentWaypoint(0);
                                Navigator.pop(context);
                              });
                            },
                          ),
                          PopupMenuItem<String>(
                            child: const Text('Load Reversed'),
                            onTap: () {
                              Storage().realmHelper.getPlan(_currentItems[index], true).then((value) {
                                Navigator.pop(context);
                                Storage().route.copyFrom(value);
                                Storage().route.setCurrentWaypoint(0);
                              });
                            },
                          ),
                          PopupMenuItem<String>(
                            child: const Text('Delete'),
                            onTap: () {
                              Storage().realmHelper.deletePlan(_currentItems[index]);
                              setState(() {
                                _currentItems.removeAt(index);
                              });
                            },
                          ),
                        ],),
                    );
                  },
                )
            ),
          ],)
      );
  }

  @override
  Widget build(BuildContext context) {
    _currentItems = Storage().realmHelper.getPlans();
    return _makeContent();
  }
}

