import 'package:avaremp/storage.dart';
import 'package:avaremp/wnb_screen.dart';
import 'package:flutter/material.dart';
import 'aircraft_screen.dart';
import 'checklist_screen.dart';
import 'documents_screen.dart';
import 'download_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';
import 'openaip_screen.dart';
import 'data/openaip_db_sync_helper.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await Storage().init();
  await OpenAipDbSyncHelper().initializeDatabases();
  
  // Start auto sync every 30 sec
  OpenAipDbSyncHelper().enableSync();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: Storage().themeNotifier,
      builder: (context, value, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) =>
                Storage().settings.showIntro() ? const OnBoardingScreen() : const MainScreen(),
            '/download': (context) => const DownloadScreen(),
            '/documents': (context) => const DocumentsScreen(),
            '/aircraft': (context) => const AircraftScreen(),
            '/checklists': (context) => const ChecklistScreen(),
            '/wnb': (context) => const WnbScreen(),
            '/openAip': (context) => const OpenAipScreen(),
          },
          theme: value,
        );
      },
    );
  }
}
