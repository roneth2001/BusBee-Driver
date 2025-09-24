import 'package:busbee_passenger/screens/driverDashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class BusDriverLoginScreen extends StatefulWidget {
  const BusDriverLoginScreen({Key? key}) : super(key: key);

  @override
  State<BusDriverLoginScreen> createState() => _BusDriverLoginScreenState();
}

class _BusDriverLoginScreenState extends State<BusDriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _busNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _message = '';
  bool _isSuccess = false;

  late DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
    } catch (e) {
      setState(() {
        _message = 'Firebase initialization error: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> verifyCredentials(String busNumber, String password) async {
  try {
    print("Fetching all buses from Firebase...");
    
    // Get all buses without using orderByChild to avoid index requirement
    final snapshot = await _databaseRef.child('buses').get();
    
    if (!snapshot.exists) {
      print("No buses found in database");
      return null;
    }
    
    print("Buses found, searching for matching credentials...");
    final raw = Map<Object?, Object?>.from(snapshot.value as Map);
    
    for (final entry in raw.entries) {
      final busData = Map<String, dynamic>.from(entry.value as Map);
      
      // Check if this bus matches our criteria
      if (busData['busNumber'] == busNumber && busData['password'] == password) {
        busData['id'] = entry.key;
        print("Login successful for bus: ${busData['busNumber']}");
        return busData;
      }
    }
    
    print("No matching bus found with provided credentials");
    return null;
    
  } catch (e) {
    print('Error verifying credentials: $e');
    return null;
  }
}

  Future<void> _loginDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    final busNumber = _busNumberController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final busData = await verifyCredentials(busNumber, password);
      if (busData != null) {
        setState(() {
          _message = 'Login successful! Redirecting to dashboard...';
          _isSuccess = true;
        });
        
        // Wait a moment to show success message, then navigate
        await Future.delayed(const Duration(seconds: 1));
        
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BusDriverDashboard(busData: busData),
          ),
        );
      } else {
        setState(() {
          _message = 'Invalid bus number or password. Please try again.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Login error: ${e.toString()}';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _clearForm() {
    _busNumberController.clear();
    _passwordController.clear();
    setState(() {
      _message = '';
      _isSuccess = false;
    });
  }

  Future<void> _launchWebsite() async {
    try {
      final Uri url = Uri.parse('https://gwtechnologiez.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching without mode specification
        await launchUrl(url);
      }
    } catch (e) {
      print('Error launching website: $e');
      // Show a snackbar or dialog to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open website. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      
                      // Logo/Header Section
                      Container(
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Bus Driver Login',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your bus credentials',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Bus Number Field
                      TextFormField(
                        controller: _busNumberController,
                        decoration: InputDecoration(
                          labelText: 'Bus Number',
                          hintText: 'Enter your bus number (e.g., NB 0001)',
                          prefixIcon: const Icon(Icons.directions_bus_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[600]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your bus number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[600]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginDriver,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Message Display Area
                      if (_message.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isSuccess ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isSuccess ? Colors.green[200]! : Colors.red[200]!,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _isSuccess ? Icons.check_circle : Icons.error,
                                color: _isSuccess ? Colors.green[600] : Colors.red[600],
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _message,
                                style: TextStyle(
                                  color: _isSuccess ? Colors.green[800] : Colors.red[800],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      
                      // Clear Button (only show after login attempt)
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: OutlinedButton(
                            onPressed: _clearForm,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 50),
                      
                      // Test Credentials
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Test Credentials:',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bus Number: NB 0001',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Password: abc123',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Powered by ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  GestureDetector(
                    onTap: _launchWebsite,
                    child: Text(
                      'GW Technology',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
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