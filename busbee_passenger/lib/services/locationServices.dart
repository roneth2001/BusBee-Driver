// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart'; // <-- important
// import 'package:geolocator/geolocator.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: true,                        // starts once app launches
//       isForegroundMode: true,                 // persistent notification
//       notificationChannelId: 'location_tracking',
//       initialNotificationTitle: 'BusBee Driver',
//       initialNotificationContent: 'Tracking your location...',
//       foregroundServiceNotificationId: 888,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//   );
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   try {
//     // 1) Init Firebase in BG isolate
//     await Firebase.initializeApp();

//     // 2) Load driver id from shared prefs (ensure not empty)
//     final prefs = await SharedPreferences.getInstance();
//     final driverId = prefs.getString('driver_id')?.trim();
//     final effectiveDriverId = (driverId == null || driverId.isEmpty)
//         ? 'default_driver'
//         : driverId;

//     final DatabaseReference locationRef =
//         FirebaseDatabase.instance.ref('drivers/$effectiveDriverId/location');

//     // 3) Single stop listener
//     service.on('stop').listen((_) async {
//       await _positionStream?.cancel();
//       _positionStream = null;
//       if (service is AndroidServiceInstance) {
//         service.stopSelf();
//       }
//     });

//     // 4) Preconditions: services + permission
//     final servicesOn = await Geolocator.isLocationServiceEnabled();
//     if (!servicesOn) {
//       _notify(service,
//           title: 'BusBee Driver - Error',
//           content: 'Location services disabled');
//       return;
//     }

//     // NOTE: Don’t request UI perms here (no UI in BG). Assume you asked before starting service.
//     final perm = await Geolocator.checkPermission();
//     if (perm == LocationPermission.denied ||
//         perm == LocationPermission.deniedForever) {
//       _notify(service,
//           title: 'BusBee Driver - Error',
//           content: 'Location permission not granted');
//       return;
//     }

//     // 5) Start stream (battery-aware)
//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 10, // meters
//       // If you see issues on some OEMs, remove timeLimit below.
//       // timeLimit: Duration(seconds: 60),
//     );

//     debugPrint('Starting background location stream…');

//     // Optional throttle: send at most once every 5s
//     DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
//     const throttle = Duration(seconds: 5);

//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position pos) async {
//         try {
//           final now = DateTime.now();
//           if (now.difference(_lastSent) < throttle) return;
//           _lastSent = now;

//           // Push to Firebase
//           await locationRef.set({
//             'latitude': pos.latitude,
//             'longitude': pos.longitude,
//             'speed': pos.speed,
//             'heading': pos.heading,
//             'accuracy': pos.accuracy,
//             'timestamp': ServerValue.timestamp,
//           });

//           // Update foreground notification
//           final hh = now.hour.toString().padLeft(2, '0');
//           final mm = now.minute.toString().padLeft(2, '0');
//           _notify(service,
//               title: 'BusBee Driver - Active',
//               content:
//                   'Last: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} @ $hh:$mm');
//         } catch (e) {
//           debugPrint('Error writing to Firebase: $e');
//           _notify(service,
//               title: 'BusBee Driver - Warning',
//               content: 'Write error, retrying…');
//         }
//       },
//       onError: (error) {
//         debugPrint('Location stream error: $error');
//         _notify(service,
//             title: 'BusBee Driver - Warning',
//             content: 'Location error, retrying…');
//       },
//       cancelOnError: false,
//     );
//   } catch (e) {
//     debugPrint('Service init error: $e');
//     _notify(service,
//         title: 'BusBee Driver - Error',
//         content: 'Init failed: $e');
//   }
// }

// StreamSubscription<Position>? _positionStream;

// void _notify(ServiceInstance service, {required String title, required String content}) async {
//   if (service is AndroidServiceInstance) {
//     await service.setForegroundNotificationInfo(
//       title: title,
//       content: content,
//     );
//   }
// }

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   // iOS can’t run forever; keep this for fetch/significant-changes setups later.
//   return true;
// }
