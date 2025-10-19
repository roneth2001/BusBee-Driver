// // lib/background_service.dart
// import 'dart:async';
// import 'dart:ui';

// import 'package:flutter/widgets.dart'; // WidgetsFlutterBinding & DartPluginRegistrant
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// import 'package:geolocator/geolocator.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';

// // ⬇️ change this import path if your firebase_options.dart lives elsewhere
// import 'package:busbee_passenger/firebase_options.dart';

// const _channelId = 'bus_tracking_channel';

// StreamSubscription<Position>? _sub;

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   // 🔧 Required in background isolates so plugins (Geolocator/Firebase/etc.) work
//   DartPluginRegistrant.ensureInitialized();

//   // 🔧 Initialize Flutter bindings + Firebase again (background isolate != main isolate)
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   // Promote to a foreground service on Android so OS doesn’t kill it
//   if (service is AndroidServiceInstance) {
//     await service.setAsForegroundService();
//     await service.setForegroundNotificationInfo(
//       title: 'Bus is Live',
//       content: 'Sharing location in background',
//     );
//   }

//   final db = FirebaseDatabase.instance.ref();
//   String? busId;

//   // Receive bus id from UI
//   service.on('setBus').listen((event) {
//     busId = event?['busId'] as String?;
//   });

//   // Graceful stops from UI
//   service.on('disposeStream').listen((_) async {
//     await _sub?.cancel();
//     _sub = null;
//   });

//   service.on('stopService').listen((_) async {
//     await _sub?.cancel();
//     _sub = null;
//     if (service is AndroidServiceInstance) {
//       await service.stopSelf();
//     }
//   });

//   // Configure continuous background location stream
//   final settings = const LocationSettings(
//     accuracy: LocationAccuracy.high, // use balanced if you want less battery use
//     distanceFilter: 15,              // meters between updates
//   );

//   _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
//     (pos) async {
//       final id = busId;
//       if (id == null) return;

//       try {
//         await db.child('buses').child(id).update({
//           'currentLocation':
//               '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
//           'latitude': pos.latitude,
//           'longitude': pos.longitude,
//           'lastLocationUpdate': ServerValue.timestamp,
//           'isOnline': true,
//         });
//       } catch (_) {
//         // swallow DB errors in background
//       }

//       if (service is AndroidServiceInstance) {
//         service.setForegroundNotificationInfo(
//           title: 'Bus is Live',
//           content:
//               'Lat ${pos.latitude.toStringAsFixed(5)}, Lng ${pos.longitude.toStringAsFixed(5)}',
//         );
//       }
//     },
//   );
// }

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStart: false, // you decide when to start (e.g., on dashboard go-live)
//       notificationChannelId: _channelId,
//       foregroundServiceTypes: [
//         AndroidForegroundType.location,
//         AndroidForegroundType.dataSync,
//       ],
//       initialNotificationTitle: 'Starting…',
//       initialNotificationContent: 'Preparing background tracking',
//     ),
//     iosConfiguration: IosConfiguration(
//       onForeground: onStart,
//       onBackground: _onIosBackground,
//       autoStart: false,
//     ),
//   );
// }

// @pragma('vm:entry-point')
// Future<bool> _onIosBackground(ServiceInstance service) async {
//   // iOS background hook (keep true)
//   return true;
// }
