import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UserProfile {
  final String name;
  final String email;
  final String photoUrl;

  UserProfile({
    required this.name,
    required this.email,
    required this.photoUrl,
  });
}

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  UserProfile? _currentUser;
  bool _isLoading = false;

  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _currentUser = UserProfile(
          name: account.displayName ?? "Google User",
          email: account.email,
          photoUrl: account.photoUrl ?? "",
        );
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
    // Attempt silent sign-in to restore past session if available
    _googleSignIn.signInSilently().catchError((_) => null);
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      _isLoading = false;
      notifyListeners();
      return googleUser != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Direct reset in case network is disconnected
      _currentUser = null;
      notifyListeners();
    }
  }
}
