// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'firebase_options.dart';
import 'screens/loginscreen.dart';

StreamSubscription<Position>? _posSub;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Optional: keep screen awake on driver devices when app is open
  WakelockPlus.enable();

  // Ask runtime permissions once on boot (you can move this after login if you prefer)
  await _requestRuntimePermissions();

  // Start background-capable location stream (single engine; Geolocator runs its own Android service)
  await _startLocationStream();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusBee Driver',
      theme: ThemeData(useMaterial3: true),
      home: const BusDriverLoginScreen(),
    );
  }
}

Future<void> _requestRuntimePermissions() async {
  // Foreground location
  final whenInUse = await Permission.locationWhenInUse.request();
  if (!whenInUse.isGranted) {
    debugPrint('locationWhenInUse denied.');
    return;
  }
  // Background location (Android 10+)
  await Permission.locationAlways.request();

  // Android 13+ notifications (so Geolocator can show its FG notification)
  if (Platform.isAndroid && await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> _startLocationStream() async {
  // Ensure system location is enabled
  if (!await Geolocator.isLocationServiceEnabled()) {
    debugPrint('Location services are disabled.');
    return;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
    debugPrint('Location permission not granted.');
    return;
  }

  final LocationSettings settings = Platform.isAndroid
      ?  AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
          intervalDuration: Duration(seconds: 15),
          // 👇 This makes Android start a proper foreground service internally
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'BusBee Driver',
            notificationText: 'Updating location in background...',
            setOngoing: true,
            enableWakeLock: true,
            notificationIcon: AndroidResource(
              name: 'ic_stat_location', // res/drawable/ic_stat_location.xml
              defType: 'drawable',
            ),
          ),
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        );

  await _posSub?.cancel();
  _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
    (pos) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final driverId = prefs.getString('driver_id')?.trim();
        final effectiveDriverId = (driverId == null || driverId.isEmpty) ? 'default_driver' : driverId;

        await FirebaseDatabase.instance
            .ref('drivers/$effectiveDriverId/location')
            .set({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('Realtime DB write error: $e');
      }
    },
    onError: (e) => debugPrint('Location stream error: $e'),
    cancelOnError: false,
  );
}
