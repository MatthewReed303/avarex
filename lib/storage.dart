import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

// put all singletons here.

import 'package:avaremp/constants.dart';
import 'package:avaremp/data/main_database_helper.dart';
import 'package:avaremp/download_screen.dart';
import 'package:avaremp/flight_status.dart';
import 'package:avaremp/gdl90/ahrs_message.dart';
import 'package:avaremp/gdl90/fis_buffer.dart';
import 'package:avaremp/gdl90/gdl90_buffer.dart';
import 'package:avaremp/gps_recorder.dart';
import 'package:avaremp/gdl90/message_factory.dart';
import 'package:avaremp/gdl90/nexrad_cache.dart';
import 'package:avaremp/gdl90/nexrad_product.dart';
import 'package:avaremp/gdl90/ownship_message.dart';
import 'package:avaremp/gdl90/product.dart';
import 'package:avaremp/gdl90/traffic_cache.dart';
import 'package:avaremp/gdl90/traffic_report_message.dart';
import 'package:avaremp/gdl90/uplink_message.dart';
import 'package:avaremp/nmea/nmea_ownship_message.dart';
import 'package:avaremp/path_utils.dart';
import 'package:avaremp/pfd_painter.dart';
import 'package:avaremp/plan/plan_route.dart';
import 'package:avaremp/stack_with_one.dart';
import 'package:avaremp/unit_conversion.dart';
import 'package:avaremp/weather/airep_cache.dart';
import 'package:avaremp/weather/airsigmet_cache.dart';
import 'package:avaremp/weather/notam_cache.dart';
import 'package:avaremp/weather/taf_cache.dart';
import 'package:avaremp/weather/tfr_cache.dart';
import 'package:avaremp/udp_receiver.dart';
import 'package:avaremp/plan/waypoint.dart';
import 'package:avaremp/weather/weather_cache.dart';
import 'package:avaremp/weather/winds_cache.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app_settings.dart';
import 'data/db_general.dart';
import 'data/realm_helper.dart';
import 'destination.dart';
import 'download_manager.dart';
import 'flight_timer.dart';
import 'gdl90/message.dart';
import 'gps.dart';
import 'nmea/nmea_buffer.dart';
import 'nmea/nmea_message.dart';
import 'nmea/nmea_message_factory.dart';
import 'weather/metar_cache.dart';

class Storage {
  static final Storage _instance = Storage._internal();

  factory Storage() {
    return _instance;
  }

  Storage._internal();

  // on gps update
  final gpsChange = ValueNotifier<Position>(Gps.centerUSAPosition());
  // when plate changes
  final plateChange = ValueNotifier<int>(0);
  // when destination changes
  final timeChange = ValueNotifier<int>(0);
  final warningChange = ValueNotifier<bool>(false);
  final flightStatus = FlightStatus();
  late WindsCache winds;
  late MetarCache metar;
  late TafCache taf;
  late TfrCache tfr;
  late AirepCache airep;
  late AirSigmetCache airSigmet;
  late NotamCache notam;
  final NexradCache nexradCache = NexradCache();
  final TrafficCache trafficCache = TrafficCache();
  final StackWithOne<Position> _gpsStack = StackWithOne(Gps.centerUSAPosition());
  int myIcao = 0;
  PfdData pfdData = PfdData(); // a place to drive PFD
  GpsRecorder tracks = GpsRecorder();
  final RealmHelper realmHelper = RealmHelper();
  late final FlightTimer flightTimer;
  late final FlightTimer flightDownTimer;
  Destination? plateAirportDestination;
  late UnitConversion units;
  DownloadManager downloadManager = DownloadManager();

  List<bool> activeChecklistSteps = [];
  String activeChecklistName = "";
  static const gpsSwitchoverTimeMs = 30000; // switch GPS in 30 seconds

  final PlanRoute _route = PlanRoute("New Plan");
  PlanRoute get route => _route;
  bool gpsNoLock = false;
  int _lastMsGpsSignal = DateTime.now().millisecondsSinceEpoch;
  get lastMsGpsSignal { return _lastMsExternalSignal; } // read-only timestamp exposed for audible alerts, among any other interested parties
  int _lastMsExternalSignal = DateTime.now().millisecondsSinceEpoch - gpsSwitchoverTimeMs;
  bool gpsInternal = true;

  // gps
  final _gps = Gps();
  final _udpReceiver = UdpReceiver();
  // where all data is place. This is set on init in main
  late String dataDir;
  late String cacheDir;
  Position position = Gps.centerUSAPosition();
  double vspeed = 0;
  bool airborne = true;  
  final AppSettings settings = AppSettings();

  final Gdl90Buffer _gdl90Buffer = Gdl90Buffer();
  final NmeaBuffer _nmeaBuffer = NmeaBuffer();

  int _key = 1111;

  String getKey() {
    return (_key++).toString();
  }

  // make it double buffer to get rid of plate load flicker
  ui.Image? imagePlate;
  Uint8List? imageBytesPlate;
  LatLng? topLeftPlate;
  LatLng? bottomRightPlate;


  // to move the plate
  String lastPlateAirport = "";
  String currentPlate = "";
  List<double>? matrixPlate;
  bool dataExpired = false;
  bool chartsMissing = false;
  bool gpsNotPermitted = false;
  bool gpsDisabled = false;
  late FileCacheStore osmCache;
  late List<FileCacheStore> mesonetCache;

  // for navigation on tabs
  final GlobalKey globalKeyBottomNavigationBar = GlobalKey();

  setDestination(Destination? destination) {
    if(destination != null) {
      route.addDirectTo(Waypoint(destination));
    }
  }

  StreamSubscription<Position>? _gpsStream;
  StreamSubscription<Uint8List>? _udpStream;

  void startIO() {
    
    // GPS data receive
    // start both external and internal
    if(!gpsDisabled) {
      _gpsStream = _gps.getStream();
      _gpsStream?.onDone(() {});
      _gpsStream?.onError((obj) {});
      _gpsStream?.onData((data) {
        if (gpsInternal) {
          _lastMsGpsSignal = DateTime
              .now()
              .millisecondsSinceEpoch; // update time when GPS signal was last received
          _gpsStack.push(data);
          tracks.add(data);
        } // provide internal GPS when external is not available
      });
    }

    // GPS data receive
    _udpStream = _udpReceiver.getStream([4000, 43211, 49002], [false, false, false]);
    _udpStream?.onDone(() {
    });
    _udpStream?.onError((obj){
    });
    _udpStream?.onData((data) {
      _gdl90Buffer.put(data);
      _nmeaBuffer.put(data);
      // gdl90
      while(true) {
        Uint8List? message = _gdl90Buffer.get();
        if (null != message) {
          Message? m = MessageFactory.buildMessage(message);
          if(m != null && m is OwnShipMessage) {
            myIcao = m.icao;
            Position p = Position(longitude: m.coordinates.longitude, latitude: m.coordinates.latitude, timestamp: DateTime.timestamp(), accuracy: 0, altitude: m.altitude, altitudeAccuracy: 0, heading: m.heading, headingAccuracy: 0, speed: m.velocity, speedAccuracy: 0);
            _lastMsGpsSignal = DateTime.now().millisecondsSinceEpoch; // update time when GPS signal was last received
            _lastMsExternalSignal = _lastMsGpsSignal; // start ignoring internal GPS
            _gpsStack.push(p);
            // Record additional ownship settings for audible alerts (among other interested parties)--or perhaps these can just reside here in Storage?
            vspeed = m.verticalSpeed;
            airborne = m.airborne;
            // record waypoints for tracks.
            tracks.add(p);
          }
          if(m != null && m is TrafficReportMessage) {
            trafficCache.putTraffic(m);
          }
          if(m != null && m is AhrsMessage) {
            m.setPfd(pfdData);
          }
          if(m != null && m is UplinkMessage) {
            FisBuffer? fis = m.fis;
            if(fis != null) {
              for(Product p in fis.products) {
                if(p is NexradProduct) {
                  nexradCache.putImg(p);
                }
              }
            }
          }
        }
        else {
          break;
        }
      }
      // nmea
      while(true) {
        Uint8List? message = _nmeaBuffer.get();
        if (null != message) {
          NmeaMessage? m = NmeaMessageFactory.buildMessage(data);
          if(m != null && m is NmeaOwnShipMessage) {
            NmeaOwnShipMessage m0 = m;
            myIcao = m0.icao;
            Position p = Position(longitude: m0.coordinates.longitude, latitude: m0.coordinates.latitude, timestamp: DateTime.timestamp(), accuracy: 0, altitude: m0.altitude, altitudeAccuracy: 0, heading: m0.heading, headingAccuracy: 0, speed: m0.velocity, speedAccuracy: 0);
            _lastMsGpsSignal = DateTime.now().millisecondsSinceEpoch; // update time when GPS signal was last received
            _lastMsExternalSignal = _lastMsGpsSignal; // start ignoring internal GPS
            vspeed = m0.verticalSpeed;
            airborne = m0.altitude > 100;
            _gpsStack.push(p);
            tracks.add(p);
          }
        }
        else {
          break;
        }
      }
    });
    try {
      // Have traffic cache listen for GPS changes for distance calc and (resulting) audible alert changes
      Storage().gpsChange.addListener(Storage().trafficCache.updateTrafficDistancesAndAlerts);
    } catch (e) { }
  }

  stopIO() {
    try {
      _udpStream?.cancel();
      _udpReceiver.finish();
    }
    catch(e) {}
    try {
      _gpsStream?.cancel();
    }
    catch(e) {}
    try {
      // Have audible alerts stop listening for GPS changes
      Storage().gpsChange.removeListener(TrafficCache().handleAudibleAlerts);    
    } catch (e) {}
  }

  Future<void> init() async {
    await settings.initSettings();
    units = UnitConversion(settings.getUnits());
    flightTimer = FlightTimer(true, 0, timeChange);
    flightDownTimer = FlightTimer(false, 30 * 60, timeChange); // 30 minute down timer
    DbGeneral.set(); // set database platform
    WidgetsFlutterBinding.ensureInitialized();
    try {
      WakelockPlus.enable(); // keep screen on
    }
    catch(e) {}
    // ask for GPS permission
    await _gps.isPermissionDenied();
    position = await Gps().getLastPosition();
    _gpsStack.push(position);
    Directory dir = await getApplicationDocumentsDirectory();
    dataDir = PathUtils.getFilePath(dir.path, "avarex"); // put files in a folder
    dir = await getApplicationSupportDirectory();
    cacheDir = dir.path; // for tiles cache
    dir = Directory(dataDir);
    if(!dir.existsSync()) {
      dir.createSync();
    }

    // tiles cache
    osmCache = FileCacheStore(PathUtils.getFilePath(Storage().cacheDir, "osm"));
    mesonetCache = List.generate(5 , (index) => FileCacheStore(PathUtils.getFilePath(Storage().cacheDir, "radar$index")));

    // this is a long login process, do not await here

    String username;
    String password;
    (username, password) = realmHelper.loadCredentials();
    realmHelper.login([username, password]);
    await checkChartsExist();
    await checkDataExpiry();

    String path = join(dataDir, "256.png");
    ByteData data = await rootBundle.load("assets/images/256.png");
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes);

    winds = WeatherCache.make(WindsCache) as WindsCache;
    metar = WeatherCache.make(MetarCache) as MetarCache;
    taf = WeatherCache.make(TafCache) as TafCache;
    tfr = WeatherCache.make(TfrCache) as TfrCache;
    airep = WeatherCache.make(AirepCache) as AirepCache;
    airSigmet = WeatherCache.make(AirSigmetCache) as AirSigmetCache;
    notam = WeatherCache.make(NotamCache) as NotamCache;
    winds.download();
    metar.download();
    taf.download();
    tfr.download();
    airep.download();
    airSigmet.download();

    gpsNotPermitted = await Gps().isPermissionDenied();
    if(gpsNotPermitted) {
      Gps().requestPermissions();
    }
    gpsDisabled = await Gps().isDisabled();

    Timer.periodic(const Duration(seconds: 1), (tim) async {
      // this provides time to apps
      timeChange.value++;

      position = _gpsStack.pop();
      gpsChange.value = position; // tell everyone

      // auto switch to airport diagram
      if (FlightStatus.flightStateLanded == flightStatus.update(position.speed)) {
        loadApd() async {
          List<Destination> airports = await MainDatabaseHelper.db.findNearestAirportsWithRunways(
              LatLng(position.latitude, position.longitude), 0);
          if(airports.isNotEmpty) {
            String? plate = await PathUtils.getAirportDiagram(Storage().dataDir, airports[0].locationID);
            if(plate != null) {
              settings.setCurrentPlateAirport(airports[0].locationID);
              currentPlate = plate;
              loadPlate();
            }
          }
        }
        loadApd();
      }

      route.update(); // change to route
      int now = DateTime.now().millisecondsSinceEpoch;
      gpsInternal = ((_lastMsExternalSignal + gpsSwitchoverTimeMs) < now);

      int diff = now - _lastMsGpsSignal;
      if (diff > 2 * gpsSwitchoverTimeMs) { // no GPS signal from both sources, send warning
        gpsNoLock = true;
      }
      else {
        gpsNoLock = false;
      }

      if(timeChange.value % 5 == 0) {

        if(gpsInternal) {
          // check system for any issues
          bool permissionDenied = await Gps().isPermissionDenied();
          if(permissionDenied == false && gpsNotPermitted == true) {
            // restart GPS since permission was denied, and now its allowed
            stopIO();
            startIO();
          }
          gpsNotPermitted = permissionDenied;
          gpsDisabled = await Gps().isDisabled();
          warningChange.value =
              gpsNotPermitted || gpsDisabled || gpsNoLock || dataExpired || chartsMissing;
        }
        else {
          // remove GPS warnings as its external now
          warningChange.value = gpsNoLock || dataExpired || chartsMissing;
        }
      }

      if((timeChange.value % (Constants.weatherUpdateTimeMin * 60)) == 0) {
        winds.download();
        metar.download();
        taf.download();
        tfr.download();
        airep.download();
        airSigmet.download();
        // nexrad update
      }
      // check GPS enabled
    });
  }

  Future<void> checkDataExpiry() async {
    dataExpired = await DownloadScreenState.isAnyChartExpired();
  }

  Future<void> checkChartsExist() async {
    chartsMissing = !(await DownloadScreenState.doesAnyChartExists());
  }

  Future<void> loadPlate() async {
    String plateAirport = settings.getCurrentPlateAirport();
    plateAirportDestination = await MainDatabaseHelper.db.findAirport(plateAirport);
    String path = PathUtils.getPlatePath(dataDir, plateAirport, currentPlate);
    File file = File(path);
    Completer<ui.Image> completerPlate = Completer();
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    }
    catch(e) {
      ByteData bd = await rootBundle.load('assets/images/black.png');
      // file bad or not found
      bytes = bd.buffer.asUint8List();
    }
    imageBytesPlate = bytes;

    topLeftPlate = null;
    bottomRightPlate = null;

    ui.decodeImageFromList(bytes, (ui.Image img) {
      return completerPlate.complete(img);
    });
    ui.Image? image = await completerPlate.future; // double buffering
    if(imagePlate != null) {
      imagePlate!.dispose();
      imagePlate = null;
    }
    imagePlate = image;

    Map<String, IfdTag> exif = await readExifFromBytes(bytes);
    matrixPlate = null;
    IfdTag? tag = exif["EXIF UserComment"];
    if(null != tag) {
      List<String> tokens = tag.toString().split("|");
      if(tokens.length == 4) {
        matrixPlate = [];
        matrixPlate!.add(double.parse(tokens[0]));
        matrixPlate!.add(double.parse(tokens[1]));
        matrixPlate!.add(double.parse(tokens[2]));
        matrixPlate!.add(double.parse(tokens[3]));

        double dx = matrixPlate![0];
        double dy = matrixPlate![1];
        double lonTopLeft = matrixPlate![2];
        double latTopLeft = matrixPlate![3];
        double latBottomRight = latTopLeft + image.height / dy;
        double lonBottomRight = lonTopLeft + image.width / dx;
        topLeftPlate = LatLng(latTopLeft, lonTopLeft);
        bottomRightPlate = LatLng(latBottomRight, lonBottomRight);
      }
      else if(tokens.length == 6) { //could be made same as for other plates
        matrixPlate = [];
        matrixPlate!.add(double.parse(tokens[0]));
        matrixPlate!.add(double.parse(tokens[1]));
        matrixPlate!.add(double.parse(tokens[2]));
        matrixPlate!.add(double.parse(tokens[3]));
        matrixPlate!.add(double.parse(tokens[4]));
        matrixPlate!.add(double.parse(tokens[5]));

      }
    }

    plateChange.value++; // change in storage
  }
}


class FileCacheManager {

  static final FileCacheManager _instance = FileCacheManager._internal();

  factory FileCacheManager() {
    return _instance;
  }

  FileCacheManager._internal();

  // this must be in a singleton class.
  final CacheManager networkCacheManager = CacheManager(Config("customCache", stalePeriod: const Duration(minutes: 1)));

}
