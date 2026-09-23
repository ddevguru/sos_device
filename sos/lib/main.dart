import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'services/background_guard_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system overlay styling for dark immersion
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await StorageService.init();

  // Initialize background foreground guard communication port
  BackgroundGuardService.init();

  // If user has clap detection enabled, activate 24/7 background guard service
  if (StorageService.isClapDetectionEnabled()) {
    BackgroundGuardService().startGuard();
  }

  runApp(const SosEmergencyApp());
}

class SosEmergencyApp extends StatelessWidget {
  const SosEmergencyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeLink SOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
