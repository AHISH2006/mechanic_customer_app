import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  final double userLat;
  final double userLng;

  const TrackingScreen({
    super.key,
    required this.requestId,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  StreamSubscription? _requestSubscription;
  LatLng? _mechanicLocation;
  String? _mechanicName;
  String? _mechanicPhone;
  String? _status;

  @override
  void initState() {
    super.initState();
    _markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: LatLng(widget.userLat, widget.userLng),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    _listenToMechanic();
  }

  void _listenToMechanic() {
    _requestSubscription = FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final mLat = data['mechanicLat'] as double?;
      final mLng = data['mechanicLng'] as double?;
      
      setState(() {
        _status = data['status'] ?? 'waiting';
        _mechanicName = data['mechanicName'];
        _mechanicPhone = data['mechanicPhone'];
        if (mLat != null && mLng != null) {
          _mechanicLocation = LatLng(mLat, mLng);
          _updateMechanicMarker();
        }
      });
      
      if (_status == 'completed' || _status == 'finished') {
        _requestSubscription?.cancel();
        _showCompletionDialog();
      }
    });
  }

  void _updateMechanicMarker() {
    if (_mechanicLocation == null) return;

    _markers.removeWhere((m) => m.markerId.value == 'mechanic');
    _markers.add(
      Marker(
        markerId: const MarkerId('mechanic'),
        position: _mechanicLocation!,
        infoWindow: InfoWindow(title: _mechanicName ?? 'Mechanic'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // Zoom to fit both markers
    if (_mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          widget.userLat < _mechanicLocation!.latitude ? widget.userLat : _mechanicLocation!.latitude,
          widget.userLng < _mechanicLocation!.longitude ? widget.userLng : _mechanicLocation!.longitude,
        ),
        northeast: LatLng(
          widget.userLat > _mechanicLocation!.latitude ? widget.userLat : _mechanicLocation!.latitude,
          widget.userLng > _mechanicLocation!.longitude ? widget.userLng : _mechanicLocation!.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Service Completed"),
        content: const Text("The mechanic has finished the work. Please rate the service in your account history."),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close tracking screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.userLat, widget.userLng),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),
          
          // Mechanic Info Card
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.blue),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mechanicName ?? "Finding Mechanic...",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _status?.toUpperCase() ?? "WAITING",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_mechanicPhone != null && _mechanicPhone!.isNotEmpty)
                        IconButton(
                          onPressed: () async {
                            final Uri callUri = Uri(scheme: 'tel', path: _mechanicPhone);
                            if (await canLaunchUrl(callUri)) {
                              await launchUrl(callUri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not launch dialer')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.phone, color: Colors.green),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: _status == 'arrived' ? 1.0 : (_status == 'accepted' ? 0.5 : 0.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status == 'arrived' 
                      ? "Mechanic has arrived!" 
                      : (_status == 'accepted' ? "Mechanic is on the way" : "Waiting for acceptance"),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
