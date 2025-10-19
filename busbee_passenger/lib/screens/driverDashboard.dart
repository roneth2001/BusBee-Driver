// lib/screens/driver_dashboard.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'loginscreen.dart';

class DriverDashboard extends StatefulWidget {
  final Map<String, dynamic> busData;
  const DriverDashboard({super.key, required this.busData});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  late final DatabaseReference _db;
  late final String _busId;

  bool _isUpdatingLocation = false;
  bool _isEndingTour = false;
  bool _autoUpdateEnabled = true;

  String _currentLocation = 'Unknown';
  String _lastUpdateClock = '';
  String _toastMsg = '';
  bool _toastSuccess = false;

  Timer? _pollTimer;
  Timer? _kickoffTimer;

  // Live status from DB
  bool _online = false;
  int? _lastServerTs;
  StreamSubscription<DatabaseEvent>? _busSub;

  @override
  void initState() {
    super.initState();

    final idRaw = widget.busData['id'];
    if (idRaw == null || idRaw.toString().trim().isEmpty) {
      throw FlutterError('DriverDashboard: busData["id"] is required.');
    }
    _busId = idRaw.toString().trim();

    _db = FirebaseDatabase.instance.ref();

    _currentLocation = (widget.busData['currentLocation'] ?? 'Unknown').toString();

    // Keep screen awake while on this page
    WakelockPlus.enable();

    // Mark online
    _setOnline(true);

    // Listen to this bus node for live badges
    _listenToBusNode();

    // Start auto updates
    _startAutoUpdates();
  }

  @override
  void dispose() {
    // Stop timers
    _stopAutoUpdates();

    // Unsubscribe DB
    _busSub?.cancel();
    _busSub = null;

    // Mark offline only if still mounted path decides to end via button.
    // (Many apps prefer marking offline on explicit "End Tour".)
    // Here we don't force offline on dispose to avoid false negatives.

    // Release wakelock
    WakelockPlus.disable();

    super.dispose();
  }

  void _listenToBusNode() {
    _busSub = _db.child('buses').child(_busId).onValue.listen((event) {
      final data = (event.snapshot.value ?? {}) as Map? ?? {};
      final isOnline = data['isOnline'] == true;
      final ts = data['lastLocationUpdate'];
      if (!mounted) return;
      setState(() {
        _online = isOnline;
        if (ts is int) _lastServerTs = ts;
      });
    }, onError: (e) {
      debugPrint('Bus node listen error: $e');
    });
  }

  void _startAutoUpdates() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (_autoUpdateEnabled && !_isUpdatingLocation && !_isEndingTour) {
        _updateLocationSilently();
      }
    });

    _kickoffTimer?.cancel();
    _kickoffTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_autoUpdateEnabled && !_isUpdatingLocation) {
        _updateLocationSilently();
      }
    });
  }

  void _stopAutoUpdates() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _kickoffTimer?.cancel();
    _kickoffTimer = null;
  }

  void _toggleAutoUpdate() {
    setState(() => _autoUpdateEnabled = !_autoUpdateEnabled);
    if (_autoUpdateEnabled) {
      _startAutoUpdates();
    } else {
      _stopAutoUpdates();
    }
  }

  Future<void> _setOnline(bool val) async {
    try {
      await _db.child('buses').child(_busId).update({'isOnline': val});
    } catch (e) {
      debugPrint('setOnline error: $e');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    // Check service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      setState(() {
        _toastMsg = 'Location services are disabled. Please enable and retry.';
        _toastSuccess = false;
      });
      return false;
    }

    // Check permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        if (!mounted) return false;
        setState(() {
          _toastMsg = 'Location permission denied.';
          _toastSuccess = false;
        });
        return false;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return false;
      setState(() {
        _toastMsg = 'Location permission permanently denied. Enable in Settings.';
        _toastSuccess = false;
      });
      return false;
    }
    return true;
  }

  Future<void> _updateLocationSilently() async {
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) return;

      if (!mounted) return;
      setState(() => _isUpdatingLocation = true);

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ),
      );

      final locStr =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';

      await _db.child('buses').child(_busId).update({
        'currentLocation': locStr,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'lastLocationUpdate': ServerValue.timestamp,
      });

      if (!mounted) return;
      setState(() {
        _currentLocation = locStr;
        _lastUpdateClock =
            TimeOfDay.fromDateTime(DateTime.now()).format(context);
      });
    } catch (e) {
      debugPrint('Auto update error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _updateLocationManually() async {
    if (!mounted) return;
    setState(() {
      _isUpdatingLocation = true;
      _toastMsg = '';
    });

    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        if (!mounted) return;
        setState(() => _isUpdatingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final locStr =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';

      await _db.child('buses').child(_busId).update({
        'currentLocation': locStr,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'lastLocationUpdate': ServerValue.timestamp,
      });

      if (!mounted) return;
      setState(() {
        _currentLocation = locStr;
        _lastUpdateClock =
            TimeOfDay.fromDateTime(DateTime.now()).format(context);
        _toastMsg = 'Location updated successfully!';
        _toastSuccess = true;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Text(_toastMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toastMsg = 'Failed to update location: $e';
        _toastSuccess = false;
      });
    } finally {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _endTour() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('End Tour'),
            content: const Text(
                'Are you sure you want to end your tour and log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('End Tour'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    if (!mounted) return;
    setState(() => _isEndingTour = true);

    try {
      // Stop auto updates first
      _stopAutoUpdates();

      // Mark offline + end time
      await _db.child('buses').child(_busId).update({
        'isOnline': false,
        'tourEndTime': ServerValue.timestamp,
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusDriverLoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toastMsg = 'Failed to end tour: $e';
        _toastSuccess = false;
        _isEndingTour = false;
      });
    }
  }

  Future<void> _launchGw() async {
    final url = Uri.parse('https://gwtechnologiez.com');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final busNumber = (widget.busData['busNumber'] ?? 'N/A').toString();
    final routeName = (widget.busData['routeName'] ?? 'Unknown').toString();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Bus $busNumber Dashboard'),
        backgroundColor: const Color(0xFFFF0000),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: _autoUpdateEnabled ? 'Auto-update ON' : 'Auto-update OFF',
            onPressed: _toggleAutoUpdate,
            icon: Icon(_autoUpdateEnabled ? Icons.gps_fixed : Icons.gps_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Bus Info Card ---
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(Icons.directions_bus,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bus $busNumber',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Route: $routeName',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _online
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _online
                                              ? Colors.green
                                              : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _online ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          color: _online
                                              ? Colors.green[800]
                                              : Colors.red[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Current Location',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      if (_lastUpdateClock.isNotEmpty)
                                        Text(
                                          'Updated: $_lastUpdateClock',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _currentLocation,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _isUpdatingLocation
                                              ? Colors.orange
                                              : Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _autoUpdateEnabled
                                            ? (_isUpdatingLocation
                                                ? 'Updating...'
                                                : 'Auto-updating every 15s')
                                            : 'Auto-update OFF',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_lastServerTs != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Server TS: $_lastServerTs',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600]),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Manual Update ---
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isUpdatingLocation
                            ? null
                            : _updateLocationManually,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _isUpdatingLocation
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Updating Location...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.my_location, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Update Location Now',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- End Tour ---
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isEndingTour ? null : _endTour,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _isEndingTour
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Ending Tour...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'End Tour & Logout',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    if (_toastMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              _toastSuccess
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: 18,
                              color:
                                  _toastSuccess ? Colors.green : Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _toastMsg,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _toastSuccess
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --- Footer ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Powered by ',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                  GestureDetector(
                    onTap: _launchGw,
                    child: Text(
                      'GW Technology (Pvt) Ltd',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
