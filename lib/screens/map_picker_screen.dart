import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final double currentLat;
  final double currentLng;

  const MapPickerScreen({
    super.key,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  late CameraPosition _initialPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.currentLat, widget.currentLng);
    _initialPosition = CameraPosition(target: _selectedLocation, zoom: 16.0);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // No setState here — the pin is a fixed overlay in the center,
  // so we only need to track the coordinate, not rebuild the widget tree.
  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final myLocation = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(myLocation, 16.0),
      );
      _selectedLocation = myLocation;
    } catch (e) {
      // Fallback to last known position on timeout or error
      try {
        Position? position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          final myLocation = LatLng(position.latitude, position.longitude);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(myLocation, 16.0),
          );
          _selectedLocation = myLocation;
          return;
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not auto-detect location.')),
        );
      }
    }
  }

  void _confirmLocation() {
    Navigator.pop(context, _selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Responsive scaling
    final isSmallPhone = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    final pinSize = isTablet ? 60.0 : (isSmallPhone ? 38.0 : 50.0);

    final fabSize = isTablet ? 48.0 : (isSmallPhone ? 32.0 : 40.0);
    final fabIconSize = isTablet ? 26.0 : (isSmallPhone ? 18.0 : 22.0);
    final fabSpacing = screenHeight * 0.015;
    final fabRight = screenWidth * 0.04;
    final fabBottom = screenHeight * 0.28;

    final bottomCardMarginH = screenWidth * 0.05;
    final bottomCardBottom = screenHeight * 0.035;
    final bottomCardPadding = screenWidth * 0.05;
    final bottomCardRadius = isTablet ? 20.0 : 16.0;

    final cardTitleSize = isTablet ? 20.0 : (isSmallPhone ? 14.0 : 18.0);
    final cardSubSize = isTablet ? 16.0 : (isSmallPhone ? 12.0 : 14.0);
    final buttonTextSize = isTablet ? 18.0 : (isSmallPhone ? 13.0 : 16.0);
    final buttonVerticalPad = isTablet ? 18.0 : (isSmallPhone ? 12.0 : 16.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Confirm Location",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22.0 : (isSmallPhone ? 16.0 : 18.0),
          ),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            // Reduce map memory usage
            liteModeEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
          ),

          // Custom Fixed Marker in the center
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: pinSize * 0.8),
              child: Icon(Icons.location_pin, color: Colors.red, size: pinSize),
            ),
          ),

          // Custom Action Floating Buttons
          Positioned(
            right: fabRight,
            bottom: fabBottom,
            child: Column(
              children: [
                SizedBox(
                  width: fabSize,
                  height: fabSize,
                  child: FloatingActionButton(
                    heroTag: "myLocation",
                    onPressed: _goToCurrentLocation,
                    backgroundColor: Colors.blue,
                    mini: true,
                    child: Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: fabIconSize,
                    ),
                  ),
                ),
                SizedBox(height: fabSpacing),
                SizedBox(
                  width: fabSize,
                  height: fabSize,
                  child: FloatingActionButton(
                    heroTag: "zoomIn",
                    onPressed: _zoomIn,
                    backgroundColor: Colors.white,
                    mini: true,
                    child: Icon(
                      Icons.add,
                      color: Colors.black87,
                      size: fabIconSize,
                    ),
                  ),
                ),
                SizedBox(height: fabSpacing * 0.5),
                SizedBox(
                  width: fabSize,
                  height: fabSize,
                  child: FloatingActionButton(
                    heroTag: "zoomOut",
                    onPressed: _zoomOut,
                    backgroundColor: Colors.white,
                    mini: true,
                    child: Icon(
                      Icons.remove,
                      color: Colors.black87,
                      size: fabIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Action Bar at the bottom
          Positioned(
            bottom: bottomCardBottom,
            left: bottomCardMarginH,
            right: bottomCardMarginH,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(bottomCardRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: EdgeInsets.all(bottomCardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Is this your exact location?",
                    style: TextStyle(
                      fontSize: cardTitleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.008),
                  Text(
                    "Drag the map to move the pin exactly to where your vehicle is located.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: cardSubSize,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _goToCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        "AUTO DETECT",
                        style: TextStyle(
                          fontSize: buttonTextSize * 0.9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue, width: 1.5),
                        padding: EdgeInsets.symmetric(
                          vertical: buttonVerticalPad * 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: buttonVerticalPad,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "CONFIRM LOCATION",
                        style: TextStyle(
                          fontSize: buttonTextSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
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
