import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send request confirmation — saves in-app notification + queues email
  Future<void> sendRequestConfirmation({
    required String requestId,
    required double lat,
    required double lng,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Fetch user profile for name and email
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = userDoc.data();
    final userName = profile?['name'] ?? 'Customer';
    final userEmail = profile?['email'] ?? user.email ?? '';
    final vehicleType = profile?['vehicleType'] ?? '';
    final vehicleBrand = profile?['vehicleBrand'] ?? '';

    // 1. Save in-app notification
    await _firestore.collection('notifications').add({
      'userId': user.uid,
      'title': 'Help Request Submitted',
      'body':
          'Your mechanic help request has been submitted successfully. '
          'A nearby mechanic will be assigned to you shortly.',
      'type': 'request_submitted',
      'requestId': requestId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Queue email notification via Firestore 'mail' collection
    //    Works with Firebase Extension "Trigger Email from Firestore"
    if (userEmail.isNotEmpty) {
      await _firestore.collection('mail').add({
        'to': [userEmail],
        'message': {
          'subject':
              '🔧 Mechanic Help — Request Confirmed (#${requestId.substring(0, 6)})',
          'html':
              '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #E53935, #C62828); padding: 24px; border-radius: 12px 12px 0 0;">
    <h1 style="color: white; margin: 0; font-size: 24px;">🔧 Mechanic Help</h1>
    <p style="color: rgba(255,255,255,0.8); margin: 4px 0 0;">Roadside Assistance</p>
  </div>
  
  <div style="background: #ffffff; padding: 24px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
    <h2 style="color: #333; margin-top: 0;">Hello $userName,</h2>
    
    <p style="color: #555; line-height: 1.6;">
      Your mechanic help request has been <strong style="color: #E53935;">submitted successfully</strong>. 
      A nearby mechanic will be assigned to assist you shortly.
    </p>
    
    <div style="background: #f5f5f5; border-radius: 8px; padding: 16px; margin: 16px 0;">
      <h3 style="color: #333; margin-top: 0; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Request Details</h3>
      <table style="width: 100%; border-collapse: collapse;">
        <tr>
          <td style="padding: 6px 0; color: #888; font-size: 14px;">Request ID</td>
          <td style="padding: 6px 0; color: #333; font-weight: bold; text-align: right; font-size: 14px;">#${requestId.substring(0, 8)}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #888; font-size: 14px;">Vehicle</td>
          <td style="padding: 6px 0; color: #333; font-weight: bold; text-align: right; font-size: 14px;">$vehicleType — $vehicleBrand</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #888; font-size: 14px;">Location</td>
          <td style="padding: 6px 0; color: #333; font-weight: bold; text-align: right; font-size: 14px;">${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #888; font-size: 14px;">Status</td>
          <td style="padding: 6px 0; color: #FF9800; font-weight: bold; text-align: right; font-size: 14px;">⏳ Waiting for mechanic</td>
        </tr>
      </table>
    </div>
    
    <p style="color: #555; line-height: 1.6; font-size: 14px;">
      You will receive another notification once a mechanic accepts your request and is on the way.
    </p>
    
    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
    <p style="color: #999; font-size: 12px; margin: 0;">
      This is an automated message from Mechanic Help. Do not reply to this email.
    </p>
  </div>
</div>
''',
        },
      });
    }
  }

  /// Get notifications for the current user (stream)
  Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
