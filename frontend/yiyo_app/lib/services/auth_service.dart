import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName(username);

    await _firestore.collection("users").doc(credential.user!.uid).set({
      "uid": credential.user!.uid,
      "email": email,
      "display_name": username,
      "created_at": DateTime.now().toUtc().toIso8601String(),
      "report_count": 0,
      "contributor_level": "Rookie",
    }, SetOptions(merge: true));
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }
}