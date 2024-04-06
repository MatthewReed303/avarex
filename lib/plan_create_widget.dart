import 'package:avaremp/plan_route.dart';
import 'package:flutter/material.dart';
import 'package:avaremp/storage.dart';

class PlanCreateWidget extends StatefulWidget {
  const PlanCreateWidget({super.key});

  @override
  State<StatefulWidget> createState() => PlanCreateWidgetState();
}

class PlanCreateWidgetState extends State<PlanCreateWidget> {

  String _route = Storage().settings.getLastRouteEntry();
  bool _getting = false;

  @override
  Widget build(BuildContext context) {

    return Container(padding: const EdgeInsets.all(0),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0), child: const Text("Create", style: TextStyle(fontWeight: FontWeight.w800),),),
        const Padding(padding: EdgeInsets.all(10)),
        Visibility(visible: _getting, child: const CircularProgressIndicator(),),
        const Padding(padding: EdgeInsets.all(10)),
        Container(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child:TextFormField(
            onChanged: (value)  {
              _route = value;
            },
            initialValue: _route,
            decoration: const InputDecoration(border: UnderlineInputBorder(), labelText: 'Route',))),
        const Padding(padding: EdgeInsets.all(10)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children:[
          TextButton(
            onPressed: () {
              if(_getting) {
                return;
              }
              Storage().settings.setLastRouteEntry(_route);
              setState(() {_getting = true;});
              PlanRoute.fromLine("New Plan", _route).then((value) {
                  Storage().route.copyFrom(value);
                  Storage().route.setCurrentWaypoint(0);
                  setState(() {_getting = false;});
                  Navigator.pop(context);
              });
            },
            child: const Text("Create As Entered"),),
          const Tooltip(triggerMode: TooltipTriggerMode.tap, message: "Enter all the waypoints separated by spaces in the Route box.", child: Icon(Icons.info))
        ]),
        const Padding(padding: EdgeInsets.all(10)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children:[
          TextButton(
            onPressed: () {
              if(_getting) {
                return;
              }
              Storage().settings.setLastRouteEntry(_route);
              setState(() {_getting = true;});
              PlanRoute.fromPreferred("New Plan", _route, Storage().route.altitude, Storage().route.altitude).then((value) {
                Storage().route.copyFrom(value);
                Storage().route.setCurrentWaypoint(0);
                setState(() {_getting = false;});
                Navigator.pop(context);
              });
            },
            child: const Text("Create IFR Preferred Route"),),
          const Tooltip(triggerMode: TooltipTriggerMode.tap, message: "Enter the departure and the destination separated by a space in the Route box.", child: Icon(Icons.info))
        ]),
      ])
    );
  }

}
