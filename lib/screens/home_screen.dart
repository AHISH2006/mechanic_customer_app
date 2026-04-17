import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'map_picker_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationStatus = "Detecting location...";
  String _locationAddress = "";
  bool _isRequesting = false;

  final _locationService = LocationService();
  final _authService = AuthService();
  final _firebaseService = FirebaseService();
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationStatus = 'Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationStatus = 'Location permissions are denied');
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _locationStatus = 'Location found';
          _locationAddress = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationStatus = 'Error getting location');
    }
  }

  void _requestHelp() async {
    setState(() => _isRequesting = true);
    try {
      final position = await _locationService.getLocation();
      if (!mounted) return;
      setState(() => _isRequesting = false);

      final LatLng? confirmedLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            currentLat: position.latitude,
            currentLng: position.longitude,
          ),
        ),
      );

      if (confirmedLocation != null && mounted) {
        setState(() => _isRequesting = true);
        final requestId = await _firebaseService.sendRequest(
          confirmedLocation.latitude,
          confirmedLocation.longitude,
        );
        await _notificationService.sendRequestConfirmation(
          requestId: requestId,
          lat: confirmedLocation.latitude,
          lng: confirmedLocation.longitude,
        );

        if (mounted) {
          setState(() => _isRequesting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Help request submitted! A confirmation email has been sent.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mechanic Help", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _notificationService.getUserNotifications(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.hasData ? snapshot.data!.docs.where((doc) => (doc.data() as Map)['read'] == false).length : 0;
              return IconButton(
                icon: Badge(
                  label: unreadCount > 0 ? Text('$unreadCount') : null,
                  isLabelVisible: unreadCount > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Greeting (Real-time)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _authService.userProfileStream,
              builder: (context, snapshot) {
                final name = snapshot.data?.data()?['name'] ?? '';
                if (name.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hi, $name 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text("How can we help you today?", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // Location Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Your Location:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        Text(_locationAddress.isNotEmpty ? _locationAddress : _locationStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Text("Need immediate assistance?", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Tap the button below to alert mechanics nearby.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // Emergency Button
            Center(
              child: GestureDetector(
                onTap: _isRequesting ? null : _requestHelp,
                child: Container(
                  width: screenWidth * 0.5,
                  height: screenWidth * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 30, spreadRadius: 10)],
                  ),
                  child: Center(
                    child: _isRequesting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                            SizedBox(height: 8),
                            Text("REQUEST\nHELP", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            const Text("Recent Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Recent Requests Stream (Filtered by User)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('userId', isEqualTo: _authService.currentUser?.uid)
                  .orderBy('time', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("No previous requests.", style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'waiting';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(status == 'waiting' ? Icons.access_time : Icons.check_circle, color: status == 'waiting' ? Colors.orange : Colors.green),
                        title: Text("Status: ${status.toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(snapshot.data?.docs.first == doc ? "Latest Request" : "Previous Request"),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
