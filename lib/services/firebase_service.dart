import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a help request and return the request document ID
  Future<String> sendRequest(double lat, double lng) async {
    final user = _auth.currentUser;

    // Fetch user profile for vehicle info
    Map<String, dynamic>? userProfile;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      userProfile = doc.data();
    }

    final docRef = await _firestore.collection('requests').add({
      'lat': lat,
      'lng': lng,
      'status': 'waiting',
      'time': FieldValue.serverTimestamp(),
      'userId': user?.uid ?? '',
      'userName': userProfile?['name'] ?? '',
      'userPhone': userProfile?['phone'] ?? '',
      'userEmail': userProfile?['email'] ?? '',
      'vehicleType': userProfile?['vehicleType'] ?? '',
      'vehicleBrand': userProfile?['vehicleBrand'] ?? '',
      'vehicleModel': userProfile?['vehicleModel'] ?? '',
      'licensePlate': userProfile?['licensePlate'] ?? '',
    });

    return docRef.id;
  }
}
