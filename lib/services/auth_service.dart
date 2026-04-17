import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current authenticated user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes for reactive UI
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create a new account and save profile to Firestore
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleType,
    required String vehicleBrand,
    String? vehicleModel,
    String? licensePlate,
  }) async {
    // 1. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2. Update display name
    await credential.user?.updateDisplayName(name.trim());

    // 3. Save full profile to Firestore
    await saveUserProfile(
      uid: credential.user!.uid,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      vehicleType: vehicleType,
      vehicleBrand: vehicleBrand.trim(),
      vehicleModel: vehicleModel?.trim(),
      licensePlate: licensePlate?.trim(),
    );

    return credential;
  }

  /// Save user profile data to Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String vehicleType,
    required String vehicleBrand,
    String? vehicleModel,
    String? licensePlate,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel ?? '',
      'licensePlate': licensePlate ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    return doc.data();
  }

  /// Get real-time user profile stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> get userProfileStream {
    return _firestore.collection('users').doc(currentUser!.uid).snapshots();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
