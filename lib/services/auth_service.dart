import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current authenticated user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes for reactive UI
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await saveUserProfile(
        uid: credential.user!.uid,
        name: name,
        phone: phone,
        email: email,
      );
    }
    return credential;
  }

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Save user profile data to Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    String? licensePlate,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType ?? '',
      'vehicleBrand': vehicleBrand ?? '',
      'vehicleModel': vehicleModel ?? '',
      'licensePlate': licensePlate ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    return doc.data();
  }

  /// Get real-time user profile stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> get userProfileStream {
    final uid = currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Check if a user document exists in Firestore
  Future<bool> checkUserDocumentExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}


