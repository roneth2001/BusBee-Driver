// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:geolocator/geolocator.dart';
// import '../firebase_options.dart';

// Future<void> initializeService(String busId) async {
//   final service = FlutterBackgroundService();

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: true,
//       isForegroundMode: true,
//       foregroundServiceNotificationId: 1001,
//       notificationChannelId: 'bus_tracking',
//       initialNotificationTitle: 'Bus Tracking Active',
//       initialNotificationContent: 'Updating location in background...',
//     ),
//     iosConfiguration: IosConfiguration(autoStart: false),
//   );

//   await service.startService();
//   service.invoke("setBusId", {"busId": busId});
// }

// @pragma('vm:entry-point')
// Future<void> onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   final db = FirebaseDatabase.instance.ref();

//   String? busId;
//   service.on("setBusId").listen((event) {
//     busId = event?['busId'];
//   });

//   Timer.periodic(const Duration(seconds: 20), (timer) async {
//     try {
//       Position pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       if (busId != null) {
//         await db.child('buses/$busId').update({
//           'latitude': pos.latitude,
//           'longitude': pos.longitude,
//           'lastLocationUpdate': ServerValue.timestamp,
//         });
//       }

//       if (service is AndroidServiceInstance) {
//         service.setForegroundNotificationInfo(
//           title: "Bus Tracking Active",
//           content:
//               "Last update: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}",
//         );
//       }

//       print("📍 Background update for $busId: ${pos.latitude}, ${pos.longitude}");
//     } catch (e) {
//       print("❌ Background location error: $e");
//     }
//   });
// }
