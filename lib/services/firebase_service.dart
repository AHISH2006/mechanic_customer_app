import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a help request and return the request document ID
  Future<String> sendRequest(double lat, double lng, String address) async {
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
      'address': address,
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

  /// Submit a rating and review for a request
  Future<void> submitReview(String requestId, double rating, String review) async {
    await _firestore.collection('requests').doc(requestId).update({
      'rating': rating,
      'review': review,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get the most recent active request for the current user
  Stream<QuerySnapshot> getActiveRequestStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    // No orderBy — avoids composite index requirement. Sort client-side.
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['waiting', 'accepted', 'arriving', 'in_progress'])
        .limit(5)
        .snapshots();
  }

  /// SIMULATION: Simulate a mechanic accepting the request
  /// In a real app, this would be done by the Mechanic App.
  Future<void> simulateAcceptance(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'accepted',
      'mechanicId': 'test_mechanic_123',
      'mechanicName': 'Ramesh Mechanic',
      'mechanicPhone': '+91 98765 43210',
      'mechanicLat': 13.0827, // Sample Chennai coordinates
      'mechanicLng': 80.2707,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }
}
