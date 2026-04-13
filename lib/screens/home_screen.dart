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

  // Single instances — avoid re-creating on every method call
  final _locationService = LocationService();
  final _authService = AuthService();
  final _firebaseService = FirebaseService();
  final _notificationService = NotificationService();
  String _userName = '';

  Future<void> _loadUserName() async {
    final profile = await _authService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _userName = profile['name'] ?? '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadUserName();
  }

  /// Discover the current location for UI display
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Location services are disabled.';
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location permissions are denied';
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Location permissions are permanently denied.';
        });
      }
      return;
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
      if (mounted) {
        setState(() {
          _locationStatus = 'Error getting location';
        });
      }
    }
  }

  void _requestHelp() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      final position = await _locationService.getLocation();

      if (!mounted) return;

      setState(() {
        _isRequesting = false;
      });

      // Navigate to map picker and wait for confirmed location
      final LatLng? confirmedLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            currentLat: position.latitude,
            currentLng: position.longitude,
          ),
        ),
      );

      // If user confirmed a location, submit the request
      if (confirmedLocation != null && mounted) {
        setState(() {
          _isRequesting = true;
        });

        // 1. Send request to Firebase
        final requestId = await _firebaseService.sendRequest(
          confirmedLocation.latitude,
          confirmedLocation.longitude,
        );

        // 2. Send notification + queue email
        await _notificationService.sendRequestConfirmation(
          requestId: requestId,
          lat: confirmedLocation.latitude,
          lng: confirmedLocation.longitude,
        );

        if (mounted) {
          setState(() {
            _isRequesting = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Help request submitted! A confirmation email has been sent.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF43A047),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error requesting help: $e");
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery.sizeOf avoids rebuilds when unrelated MediaQuery properties change
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive scaling factors
    final isSmallPhone = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    // Scaled values
    final horizontalPadding = screenWidth * 0.06;
    final verticalPadding = screenHeight * 0.02;

    final locationIconSize = isTablet ? 40.0 : (isSmallPhone ? 24.0 : 32.0);
    final locationLabelSize = isTablet ? 16.0 : (isSmallPhone ? 12.0 : 14.0);
    final locationValueSize = isTablet ? 18.0 : (isSmallPhone ? 13.0 : 16.0);

    final headingSize = isTablet ? 22.0 : (isSmallPhone ? 15.0 : 18.0);
    final subHeadingSize = isTablet ? 16.0 : (isSmallPhone ? 12.0 : 14.0);

    final emergencyButtonSize = isTablet
        ? screenWidth * 0.35
        : (isSmallPhone ? screenWidth * 0.45 : screenWidth * 0.5);
    final emergencyIconSize = isTablet ? 56.0 : (isSmallPhone ? 36.0 : 48.0);
    final emergencyTextSize = isTablet ? 26.0 : (isSmallPhone ? 16.0 : 22.0);

    final sectionTitleSize = isTablet ? 18.0 : (isSmallPhone ? 13.0 : 16.0);
    final cardTitleSize = isTablet ? 16.0 : (isSmallPhone ? 12.0 : 14.0);
    final cardSubtitleSize = isTablet ? 14.0 : (isSmallPhone ? 10.0 : 12.0);

    final sectionSpacing = screenHeight * 0.025;
    final buttonSpacing = screenHeight * 0.04;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Mechanic Help",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22.0 : (isSmallPhone ? 16.0 : 18.0),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // Notification Bell with unread badge
          StreamBuilder<QuerySnapshot>(
            stream: _notificationService.getUserNotifications(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs
                    .where((doc) =>
                        (doc.data() as Map<String, dynamic>)['read'] == false)
                    .length;
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 24),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _authService.signOut();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Greeting
                if (_userName.isNotEmpty) ...[
                  Text(
                    "Hi, $_userName 👋",
                    style: TextStyle(
                      fontSize: headingSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "How can we help you today?",
                    style: TextStyle(
                      fontSize: subHeadingSize,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: sectionSpacing),
                ],

                // Location Section
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: locationIconSize),
                      SizedBox(width: screenWidth * 0.04),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your Location:",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: locationLabelSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _locationAddress.isNotEmpty ? _locationAddress : _locationStatus,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: locationValueSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: sectionSpacing),

                // Quick Action / Emergency Area
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Need immediate assistance?",
                        style: TextStyle(
                          fontSize: headingSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        "Tap the button below to alert mechanics nearby.",
                        style: TextStyle(
                          fontSize: subHeadingSize,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: buttonSpacing),

                // Big Emergency Button
                Center(
                  child: Container(
                    width: emergencyButtonSize,
                    height: emergencyButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(244, 67, 54, 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isRequesting ? null : _requestHelp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 5,
                        padding: EdgeInsets.zero,
                      ),
                      child: _isRequesting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: emergencyIconSize),
                                SizedBox(height: screenHeight * 0.008),
                                Text(
                                  "REQUEST\nHELP",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: emergencyTextSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                SizedBox(height: sectionSpacing),

                // Recent Requests Section
                const Divider(),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  "Recent Requests",
                  style: TextStyle(
                    fontSize: sectionTitleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: screenHeight * 0.012),

                // Firebase Stream for Recent Requests
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .orderBy('time', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history, color: Colors.grey[400], size: isTablet ? 28 : 24),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Text(
                                "No previous requests.",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: subHeadingSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? 'unknown';
                        final time = data['time'] as Timestamp?;
                        final dateStr = time != null
                            ? "${time.toDate().day}/${time.toDate().month} ${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}"
                            : "Unknown time";

                        return Card(
                          margin: EdgeInsets.only(bottom: screenHeight * 0.008),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.005,
                            ),
                            leading: CircleAvatar(
                              radius: isTablet ? 24 : (isSmallPhone ? 16 : 20),
                              backgroundColor: status == 'waiting' ? Colors.orange.shade100 : Colors.green.shade100,
                              child: Icon(
                                status == 'waiting' ? Icons.access_time : Icons.check_circle,
                                color: status == 'waiting' ? Colors.orange : Colors.green,
                                size: isTablet ? 24 : (isSmallPhone ? 16 : 20),
                              ),
                            ),
                            title: Text(
                              "Status: ${status.toUpperCase()}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: cardTitleSize),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: TextStyle(color: Colors.grey[600], fontSize: cardSubtitleSize),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: isTablet ? 28 : 24,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
