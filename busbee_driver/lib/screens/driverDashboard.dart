import 'package:flutter/material.dart';

class DriverDashboard extends StatelessWidget {
  final String busNumber;
  final Map<String, dynamic> busData;

  const DriverDashboard({
    Key? key,
    required this.busNumber,
    required this.busData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard - Bus ${busData['busNumber']}'),
        backgroundColor: const Color(0xFF4facfe),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_bus,
              size: 100,
              color: Color(0xFF4facfe),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome, Driver!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Bus Number: ${busData['busNumber']}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              'Route: ${busData['routeName']}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add logout functionality
                Navigator.pop(context);
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}