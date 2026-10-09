import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class AuthService {
  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  static bool _googleInitialized = false;


  static User? get currentUser =>
      _auth.currentUser;


  static bool get usesPasswordProvider {
    return currentUser
            ?.providerData
            .any(
              (provider) =>
                  provider.providerId ==
                  "password",
            ) ??
        false;
  }


  static bool get usesGoogleProvider {
    return currentUser
            ?.providerData
            .any(
              (provider) =>
                  provider.providerId ==
                  "google.com",
            ) ??
        false;
  }


  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }


  static Future<void>
      _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize();

    _googleInitialized = true;
  }


  // ---------------------------------------------------------------------------
  // Email / password signup
  // ---------------------------------------------------------------------------

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final cleanEmail =
        email.trim();

    final cleanUsername =
        username.trim();

    final credential =
        await _auth
            .createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user =
        credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code:
            "user-creation-failed",

        message:
            "Your account could not be created.",
      );
    }

    // For email signup, the username entered on
    // the signup screen becomes the initial YIYO
    // username immediately.
      await user.updateDisplayName(
          cleanUsername,
        );

        await _createUserDocumentIfNeeded(
      user: user,

      // Preserve what they typed so we
      // can prefill Make YIYO yours.
      displayName:
          cleanUsername,

      // Do not finalize the YIYO username
      // until onboarding is completed.
      username:
          "",
    );
  }


  // ---------------------------------------------------------------------------
  // Email / password login
  // ---------------------------------------------------------------------------

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth
        .signInWithEmailAndPassword(
      email:
          email.trim(),

      password:
          password,
    );
  }


  // ---------------------------------------------------------------------------
  // Google sign-in
  // ---------------------------------------------------------------------------

  static Future<void>
      signInWithGoogle() async {
    await _initializeGoogleSignIn();

    final googleUser =
        await _googleSignIn
            .authenticate();

    final googleAuth =
        googleUser.authentication;

    final idToken =
        googleAuth.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code:
            "google-token-missing",

        message:
            "Google sign-in could not be completed.",
      );
    }

    final credential =
        GoogleAuthProvider.credential(
      idToken:
          idToken,
    );

    final result =
        await _auth
            .signInWithCredential(
      credential,
    );

    final user =
        result.user;

    if (user == null) {
      throw FirebaseAuthException(
        code:
            "google-sign-in-failed",

        message:
            "Google sign-in could not be completed.",
      );
    }

    // Google display name is NOT automatically
    // treated as the YIYO username.
    //
    // A first-time Google user should still
    // choose their unique YIYO username once.
    await _createUserDocumentIfNeeded(
      user:
          user,

      displayName:
          user.displayName ?? "",

      username:
          "",
    );
  }


  // ---------------------------------------------------------------------------
  // Re-authentication
  // ---------------------------------------------------------------------------

  static Future<void>
      reauthenticateWithPassword(
    String password,
  ) async {
    final user =
        currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code:
            "no-current-user",

        message:
            "You are no longer signed in.",
      );
    }

    final email =
        user.email?.trim() ?? "";

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code:
            "email-unavailable",

        message:
            "This account does not have an email address.",
      );
    }

    final credential =
        EmailAuthProvider.credential(
      email:
          email,

      password:
          password,
    );

    await user
        .reauthenticateWithCredential(
      credential,
    );

    // Force Firebase to issue a fresh token
    // carrying the new auth_time claim.
    await user.getIdToken(
      true,
    );
  }


  static Future<bool>
      reauthenticateWithGoogle() async {
    final user =
        currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code:
            "no-current-user",

        message:
            "You are no longer signed in.",
      );
    }

    await _initializeGoogleSignIn();

    try {
      // Force an interactive Google auth
      // rather than trusting an old session.
      await _googleSignIn.signOut();

      final googleUser =
          await _googleSignIn
              .authenticate();

      final googleAuth =
          googleUser.authentication;

      final idToken =
          googleAuth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code:
              "google-token-missing",

          message:
              "Google verification could not be completed.",
        );
      }

      final credential =
          GoogleAuthProvider.credential(
        idToken:
            idToken,
      );

      await user
          .reauthenticateWithCredential(
        credential,
      );

      await user.getIdToken(
        true,
      );

      return true;
    } on GoogleSignInException catch (e) {
      if (
          e.code ==
          GoogleSignInExceptionCode
              .canceled) {
        return false;
      }

      rethrow;
    }
  }


  // ---------------------------------------------------------------------------
  // Firestore user document
  // ---------------------------------------------------------------------------

  static Future<void>
      _createUserDocumentIfNeeded({
    required User user,
    required String displayName,
    required String username,
  }) async {
    final ref =
        _firestore
            .collection(
              "users",
            )
            .doc(
              user.uid,
            );

    final existing =
        await ref.get();

    if (existing.exists) {
      return;
    }

    final cleanDisplayName =
        displayName.trim();

    final cleanUsername =
        username.trim();

    await ref.set(
      {
        "uid":
            user.uid,

        "email":
            user.email ?? "",

        // Human-facing display value.
        //
        // For email signup this initially
        // matches the username.
        //
        // For Google it can contain the
        // Google account's display name.
        "display_name":
            cleanDisplayName,

        // Actual YIYO username.
        //
        // Email signup already chose this
        // on AuthScreen, so save it now.
        //
        // Google leaves this blank until
        // the user chooses one.
        "username":
            cleanUsername,

        "created_at":
            DateTime.now()
                .toUtc()
                .toIso8601String(),

        "report_count":
            0,

        "contributor_level":
            "Rookie",
      },
    );
  }


  // ---------------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------------

  static Future<void>
      sendPasswordResetEmail({
    required String email,
  }) async {
    await _auth
        .sendPasswordResetEmail(
      email:
          email.trim(),
    );
  }


  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  static Future<void> signOut() async {
    await _auth.signOut();
  }


  // ---------------------------------------------------------------------------
  // Deleted-account cleanup
  // ---------------------------------------------------------------------------

  static Future<void>
      finishDeletedAccountSession() async {
    try {
      await _auth.signOut();
    } finally {
      if (_googleInitialized) {
        try {
          await _googleSignIn
              .signOut();
        } catch (_) {
          // Firebase session has already
          // been cleared locally.
        }
      }
    }
  }


  // ---------------------------------------------------------------------------
  // Firebase token
  // ---------------------------------------------------------------------------

  static Future<String?> getIdToken({
    bool forceRefresh = false,
  }) async {
    return _auth
        .currentUser
        ?.getIdToken(
          forceRefresh,
        );
  }
}