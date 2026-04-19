import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'map_picker_screen.dart';

import 'tracking_screen.dart';
import '../widgets/custom_animations.dart';
import '../widgets/request_button.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationStatus = "Detecting location...";
  String _locationAddress = "";

  final _locationService = LocationService();
  final _authService = AuthService();
  final _firebaseService = FirebaseService();


  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;
    
    setState(() {
      _locationStatus = "Detecting location...";
      _locationAddress = "";
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _locationStatus = 'Location services are disabled.');
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationStatus = 'Location permissions are denied');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _locationStatus = 'Location permissions are permanently denied');
      }
      return;
    }

    try {
      // Step 3: Fetch position first
      Position position = await _locationService.getLocation();
      
      if (mounted) {
        setState(() {
          _locationStatus = 'Location found';
          // Step 6: Show Lat/Lng first as per test plan
          _locationAddress = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      }

      // Step 6: Then convert to address
      String address = await _locationService.getAddressFromLatLng(
          position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _locationAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationStatus = 'Unable to fetch location');
      }
    }
  }

  Future<void> _requestHelp() async {
    try {
      final position = await _locationService.getLocation();
      if (!mounted) return;

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
        // Fetch fresh address for the confirmed location
        final confirmedAddress = await _locationService.getAddressFromLatLng(
          confirmedLocation.latitude,
          confirmedLocation.longitude,
        );

        await _firebaseService.sendRequest(
          confirmedLocation.latitude,
          confirmedLocation.longitude,
          confirmedAddress,
        );



        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Help request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

      } else {
        throw Exception('Cancelled by user');
      }
    } catch (e) {
      if (mounted) {
        if (!e.toString().contains('Cancelled by user')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
      rethrow;
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "just now";
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return "just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes} mins ago";
    if (difference.inHours < 24) return "${difference.inHours} hours ago";
    if (difference.inDays < 7) return "${difference.inDays} days ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  void _showRequestDetails(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'waiting';
    final time = data['time'] as Timestamp?;
    final dateStr = time != null
        ? "${time.toDate().day}/${time.toDate().month}/${time.toDate().year}"
        : "N/A";
    final timeStr = time != null
        ? "${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}"
        : "N/A";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Request Details",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow(
                  Icons.tag, "Request ID", docId.toUpperCase().substring(0, 8)),
              _detailRow(Icons.location_on_outlined, "Location",
                data['address'] ?? "Lat: ${data['lat']}, Lng: ${data['lng']}"),
              _detailRow(Icons.calendar_today_outlined, "Date", dateStr),
              _detailRow(Icons.access_time_outlined, "Time", timeStr),
              _detailRow(Icons.info_outline, "Status",
                  status.toString().toUpperCase(),
                  color: status == 'waiting'
                      ? Colors.orange
                      : (status == 'accepted' ? Colors.blue : Colors.green)),
              const SizedBox(height: 30),
              if (status == 'waiting')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelRequest(docId);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("CANCEL REQUEST",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (status == 'accepted' || status == 'arriving' || status == 'in_progress')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackingScreen(
                            requestId: docId,
                            userLat: data['lat'] ?? 0.0,
                            userLng: data['lng'] ?? 0.0,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_searching),
                    label: const Text("LIVE TRACK MECHANIC",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (status == 'completed' || status == 'finished')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Payment integration coming soon! (UPI/Online)")),
                      );
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text("PAY NOW",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _cancelRequest(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: const Text(
            "Are you sure you want to remove this help request?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('requests')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Request cancelled"),
                backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mechanic Help",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
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
                    Text(
                      "Hi, $name 👋",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "How can we help you today?",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // Active Request Status Banner
            _buildActiveRequestSection(),

            // Location Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Location:",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _locationAddress.isNotEmpty
                              ? _locationAddress
                              : _locationStatus,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _locationStatus == "Detecting location..." ? null : _determinePosition,
                    icon: Icon(
                      Icons.my_location,
                      color: _locationStatus == "Detecting location..." 
                          ? Colors.grey 
                          : theme.primaryColor,
                      size: 18,
                    ),
                    label: Text(
                      "Auto Detect",
                      style: TextStyle(
                        color: _locationStatus == "Detecting location..." 
                            ? Colors.grey 
                            : theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Text(
              "Need immediate assistance?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Tap the button below to alert mechanics nearby.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Emergency Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RequestHelpButton(
                onRequest: () async {
                  // We simulate fetching mechanics logic here without managing 
                  // loading states manually as the button handles it now.
                  await _requestHelp();
                },
              ),
            ),
            
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              "Recent Requests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('userId', isEqualTo: _authService.currentUser?.uid)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      "Query Error: ${snapshot.error.toString().split(' ').take(10).join(' ')}...",
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.assignment_late_outlined,
                    message: "No recent requests",
                  );
                }
                // Sort client-side: newest first, take top 3
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aT = (a.data() as Map)['time'] as Timestamp?;
                    final bT = (b.data() as Map)['time'] as Timestamp?;
                    if (aT == null && bT == null) return 0;
                    if (aT == null) return 1;
                    if (bT == null) return -1;
                    return bT.compareTo(aT);
                  });
                final recentDocs = docs.take(3).toList();
                return AnimationLimiter(
                  child: Column(
                    children: recentDocs.asMap().entries.map((entry) {
                      int index = entry.key;
                      var doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'waiting';
                      final time = data['time'] as Timestamp?;

                      Color statusColor = Colors.orange;
                      if (status == 'accepted') statusColor = Colors.blue;
                      if (status == 'completed' || status == 'finished') statusColor = Colors.green;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 250),
                        child: SlideAnimation(
                          verticalOffset: 30.0,
                          child: FadeInAnimation(
                            child: Dismissible(
                              key: Key(doc.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                _cancelRequest(doc.id);
                              },
                              child: BouncingWidget(
                                scaleFactor: 0.98,
                                onTap: () => _showRequestDetails(data, doc.id),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                      child: Icon(
                                        status == 'waiting'
                                            ? Icons.access_time
                                            : status == 'accepted'
                                                ? Icons.directions_car
                                                : Icons.check_circle,
                                        key: ValueKey(status),
                                        color: statusColor,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Need Help",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(
                                          data['address'] ??
                                              "Loc: ${data['lat'].toStringAsFixed(2)}, ${data['lng'].toStringAsFixed(2)}",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history,
                                          size: 14, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTimeAgo(time),
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Text(
                                            status.toString().toUpperCase(),
                                            key: ValueKey(status),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      if (status == 'waiting') ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _cancelRequest(doc.id),
                                          child: const Icon(
                                              Icons.cancel_outlined,
                                              size: 20,
                                              color: Colors.red),
                                        ),
                                      ],
                                      if (status == 'accepted' || status == 'in_progress') ...[
                                        const SizedBox(width: 8),
                                        BouncingWidget(
                                          onTap: () => Navigator.push(
                                            context,
                                            SlideUpPageRoute(
                                              page: TrackingScreen(
                                                requestId: doc.id,
                                                userLat: data['lat'] ?? 0.0,
                                                userLng: data['lng'] ?? 0.0,
                                              ),
                                            ),
                                          ),
                                          child: const Icon(
                                              Icons.location_searching,
                                              size: 20,
                                              color: Colors.blue),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            }).toList(),
          ),
        );
      },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getActiveRequestStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        // Sort client-side: pick the most recent active request
        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aT = (a.data() as Map)['time'] as Timestamp?;
            final bT = (b.data() as Map)['time'] as Timestamp?;
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return bT.compareTo(aT);
          });

        final doc = sortedDocs.first;
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'waiting';
        final requestId = doc.id;
        final mechanicName = data['mechanicName'] ?? 'a mechanic';

        Color statusColor = Colors.orange;
        String statusText = "Searching for mechanics...";
        IconData statusIcon = Icons.search;

        if (status == 'accepted') {
          statusColor = Colors.blue;
          statusText = "Mechanic $mechanicName Assigned!";
          statusIcon = Icons.person_pin_circle;
        } else if (status == 'arriving' || status == 'in_progress') {
          statusColor = Colors.blue;
          statusText = "Mechanic is arriving...";
          statusIcon = Icons.directions_car;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == 'waiting' ? "Help is on the way" : "Mechanic Assigned",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != 'waiting')
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackingScreen(
                              requestId: requestId,
                              userLat: data['lat'] ?? 0.0,
                              userLng: data['lng'] ?? 0.0,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    ),
                ],
              ),

            ],
          ),
        );
      },
    );
  }
}
