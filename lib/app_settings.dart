
import 'package:avaremp/chart.dart';
import 'package:avaremp/documents_screen.dart';
import 'package:avaremp/settings_cache_provider.dart';

class AppSettings {

  late final SettingsCacheProvider provider;

  Future<void> initSettings() async {
    provider = SettingsCacheProvider();
    provider.init();
  }

  void setChartType(String chart) {
    provider.setString("key-chart-v1", chart);
  }

  String getChartType() {
    return provider.getValue("key-chart-v1", defaultValue: ChartCategory.sectional) as String;
  }

  bool getNorthUp() {
    return provider.getValue("key-north-up", defaultValue: true) as bool;
  }

  void setNorthUp(bool northUp) {
    provider.setBool("key-north-up", northUp);
  }

  void setZoom(double zoom) {
    provider.setDouble("key-chart-zoom", zoom);
  }

  double getZoom() {
    return provider.getValue("key-chart-zoom", defaultValue: 0.0) as double;
  }

  void setRotation(double rotation) {
    provider.setDouble("key-chart-rotation", rotation);
  }

  double getRotation() {
    return provider.getValue("key-chart-rotation", defaultValue: 0.0) as double;
  }

  void setCenterLatitude(double l) {
    provider.setDouble("key-chart-center-latitude", l);
  }

  double getCenterLatitude() {
    return provider.getValue("key-chart-center-latitude", defaultValue: 37.0) as double;
  }

  void setCenterLongitude(double l) {
    provider.setDouble("key-chart-center-longitude", l);
  }

  double getCenterLongitude() {
    return provider.getValue("key-chart-center-longitude", defaultValue: -95.0) as double;
  }

  void setInstruments(String instruments) {
    provider.setString("key-instruments-v10", instruments);
  }

  String getInstruments() {
    return provider.getValue("key-instruments-v10", defaultValue: "GS,ALT,MT,NXT,DIS,BRG,ETA,ETE,UPT,DNT,UTC,SRC") as String;
  }

  List<String> getLayers() {
    return (provider.getValue("key-layers-v34", defaultValue: "Nav,Circles,Chart,OSM,Weather,NOAA-Loop,TFR,Plate,Traffic,PFD,Tracks") as String).split(",");
  }

  List<bool> getLayersState() {
    return (provider.getValue("key-layers-state-v34", defaultValue: "true,true,false,false,false,false,true,false,true,false,false") as String).split(",").map((String e) => e == 'true' ? true : false).toList();
  }

  void setLayersState(List<bool> state) {
    provider.setString("key-layers-state-v33", state.map((bool e) => e.toString()).toList().join(","));
  }

  void setCurrentPlateAirport(String name) {
    provider.setString("key-current-plate-airport", name);
  }

  String getCurrentPlateAirport() {
    return provider.getValue("key-current-plate-airport", defaultValue: "") as String;
  }

  void setEmail(String name) {
    provider.setString("key-user-email", name);
  }

  String getEmail() {
    return provider.getValue("key-user-email", defaultValue: "") as String;
  }

  void setPasswordBackup(String password) {
    provider.setString("key-user-password-backup", password);
  }

  String getPasswordBackup() {
    return provider.getValue("key-user-password-backup", defaultValue: "") as String;
  }

  void setEmailBackup(String name) {
    provider.setString("key-user-email-backup", name);
  }

  String getEmailBackup() {
    return provider.getValue("key-user-email-backup", defaultValue: "") as String;
  }

  void setLastRouteEntry(String value) {
    provider.setString("key-last-route-entry", value);
  }

  String getLastRouteEntry() {
    return provider.getValue("key-last-route-entry", defaultValue: "") as String;
  }

  void setAircraft(String name) {
    provider.setString("key-user-aircraft", name);
  }

  String getAircraft() {
    return provider.getValue("key-user-aircraft", defaultValue: "") as String;
  }

  void setChecklist(String name) {
    provider.setString("key-user-checklist", name);
  }

  String getChecklist() {
    return provider.getValue("key-user-checklist", defaultValue: "") as String;
  }

  double getTas() {
    return provider.getValue("key-airplane-tas-v3", defaultValue: 100.0) as double;
  }

  void setTas(double value) {
    provider.setDouble("key-airplane-tas-v3", value);
  }

  double getFuelBurn() {
    return provider.getValue("key-airplane-fuel-burn-v3", defaultValue: 10.0) as double;
  }

  void setFuelBurn(double value) {
    provider.setDouble("key-airplane-fuel-burn-v3", value);
  }

  bool isSigned() {
    return provider.getValue("key-signed", defaultValue: false) as bool;
  }

  void setSign(bool value) {
    provider.setBool("key-signed", value);
  }

  bool showIntro() {
    return provider.getValue("key-intro", defaultValue: true) as bool;
  }

  void setIntro(bool value) {
    provider.setBool("key-intro", value);
  }

  void setDocumentPage(String name) {
    provider.setString("key-document-page-v1", name);
  }

  String getDocumentPage() {
    return provider.getValue("key-document-page-v1", defaultValue: DocumentsScreen.allDocuments) as String;
  }

  bool isAudibleAlertsEnabled() {
    return provider.getValue("key-audible-alerts", defaultValue: true) as bool;
  }

  void setAudibleAlertsEnabled(bool value) {
    provider.setBool("key-audible-alerts", value);
  }

  bool isInstrumentsVisiblePlate() {
    return provider.getValue("key-enable-instruments-plate", defaultValue: true) as bool;
  }

  void setInstrumentsVisiblePlate(bool value) {
    provider.setBool("key-enable-instruments-plate", value);
  }

}

