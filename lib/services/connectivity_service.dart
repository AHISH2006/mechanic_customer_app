import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  // Stream to listen to connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;

  // Helper to check if connected to internet
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return _isConnected(results);
  }

  // Monitor connectivity and provide simple true/false stream
  Stream<bool> get isConnectedStream => onConnectivityChanged.map(_isConnected);

  bool _isConnected(List<ConnectivityResult> results) {
    // If any of the connection types are NOT 'none', we assume joined to a network
    // Note: This doesn't guarantee internet access, just network connection.
    if (results.isEmpty) return false;
    return !results.contains(ConnectivityResult.none);
  }
}
