import 'package:avaremp/geo_calculations.dart';
import 'package:avaremp/plan_route.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'constants.dart';
import 'destination.dart';
import 'gps.dart';


class InstrumentList extends StatefulWidget {
  const InstrumentList({super.key});

  @override
  State<InstrumentList> createState() => InstrumentListState();
}

class InstrumentListState extends State<InstrumentList> {
  final List<String> _items = Storage().settings.getInstruments().split(","); // get instruments
  String _gndSpeed = "0";
  String _altitude = "0";
  String _track = "0\u00b0";
  String _timerUp = "00:00";
  String _destination = "";
  String _bearing = "0\u00b0";
  String _distance = "";
  String _utc = "00:00";
  int _countUp = 0;
  bool _doCountUp = false;

  InstrumentListState() {

    (String, String) getDistanceBearing() {
      LatLng position = Gps.toLatLng(Storage().position);

      PlanRoute? route = Storage().route;
      if(route != null) {
        Destination? d = Storage().route!.getNextWaypoint();
        if (d != null) {
          double distance = GeoCalculations().calculateDistance(
              position, d.coordinate);
          double bearing = GeoCalculations().calculateBearing(
              position, d.coordinate);
          return (distance.round().toString(), "${bearing.round()}\u00b0");
        }
      }
      return ("", "0\u00b0");
    }

    // connect to GPS
    Storage().gpsChange.addListener(() {
      setState(() {
        _gndSpeed = GeoCalculations.convertSpeed(Storage().position.speed);
        _altitude = GeoCalculations.convertAltitude(Storage().position.altitude);
        _track = GeoCalculations.convertTrack(Storage().position.heading);
        var (distance, bearing) = getDistanceBearing();
        _distance = distance;
        _bearing = bearing;
      });
    });

    // connect to dest change
    Storage().routeChange.addListener(() {
      setState(() {
        PlanRoute? route = Storage().route;

        if (route != null) {
          Destination? d = route.getNextWaypoint();
          _destination = d != null ? d.locationID : "";
          var (distance, bearing) = getDistanceBearing();
          _distance = distance;
          _bearing = bearing;
        }
      });
    });

    // up timer
    Storage().timeChange.addListener(() {
      setState(() {
        _countUp = _doCountUp ? _countUp + 1 : _countUp;
        Duration d = Duration(seconds: _countUp);
        _timerUp = d.toString().substring(2, 7);
        DateFormat formatter = DateFormat('HH:mm');
        _utc =   formatter.format(DateTime.now().toUtc());
      });
    });
  }

  // up timer
  void _startUpTimer() {
    _doCountUp = _doCountUp ? false : true;
    _countUp = 0;
    Duration d = Duration(seconds: _countUp);
    setState(() {
      _timerUp = d.toString().substring(2, 7);
    });
  }


  // make an instrument for top line
  Widget _makeInstrument(int index) {
    bool portrait = Constants.isPortrait(context);
    double width = Constants.screenWidth(context) / 6; // get more instruments in
    if(portrait) {
      width = Constants.screenWidth(context) / 4;
    }

    String value = "";
    Function() cb = () {};

    // set callbacks and connect values
    switch(_items[index]) {
      case "Gnd Speed":
        value = _gndSpeed;
        break;
      case "Alt":
        value = _altitude;
        break;
      case "Track":
        value = _track;
        break;
      case "Next":
        value = _destination;
        break;
      case "Bearing":
        value = _bearing;
        break;
      case "Distance":
        value = _distance;
        break;
      case "UTC":
        value = _utc;
        break;
      case "Up Timer":
        value = _timerUp;
        cb = _startUpTimer;
        break;
    }

    return SizedBox(
        key: Key(index.toString()),
        width: width,
        child:ListTile(
          onTap: cb,
          title: Text(_items[index], style: const TextStyle(color: Constants.instrumentsNormalLabelColor, fontWeight: FontWeight.w900, fontSize: 10, fontStyle: FontStyle.italic),),
          subtitle: Text(value, style: const TextStyle(color: Constants.instrumentsNormalValueColor, fontSize: 24, fontWeight: FontWeight.w600)
          )
        )
    );
  }

  @override
  Widget build(BuildContext context) {

    // user can rearrange widgets
    return ReorderableListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        for(int index = 0; index < _items.length; index++)
          _makeInstrument(index),
      ],
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final String item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
        // save order for next start
        Storage().settings.setInstruments(_items.join(","));
      },
    );
  }
}
