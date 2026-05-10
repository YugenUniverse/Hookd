import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/firebase_env.dart';
import '../constants/api_config.dart';
import '../utils/error_helpers.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _i = AuthService._internal();
  factory AuthService() => _i;
  AuthService._internal();

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      resetOnError: true,
    ),
  );

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _username;
  bool _isAdmin = false;
  bool _keyringLocked = false;

  // public getters
  String? get jwt => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get currentUserId => _userId;
  String? get username => _username;
  bool get isAdmin => _isAdmin;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isKeyringLocked => _keyringLocked;

  // Load tokens from secure storage.
  // Throws KeyringLockedException if secure storage cannot be accessed (e.g. libsecret locked).
  Future<void> loadFromStorage() async {
    try {
      print('Loading tokens from secure storage...');
      _accessToken = await _secure.read(key: 'access_token');
      _refreshToken = await _secure.read(key: 'refresh_token');
      _trySetUserFromJwt(_accessToken);
      _keyringLocked = false;
      if (_accessToken != null) {
        print('Successfully loaded access token from storage');
      } else {
        print('No access token found in storage');
      }
      notifyListeners();
      return;
    } on PlatformException catch (e) {
      print('PlatformException while loading tokens: ${e.code} - ${e.message}');
      _keyringLocked = true;
      throw KeyringLockedException(e.message);
    } catch (e) {
      // Other errors -> treat as no tokens but not keyring-locked
      print('Error loading tokens from storage: $e');
      _accessToken = null;
      _refreshToken = null;
      _keyringLocked = false;
      notifyListeners();
    }
  }

  // Persist tokens to secure storage. Throws KeyringLockedException on keyring error.
  Future<void> persistTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _trySetUserFromJwt(_accessToken);

    try {
      print('Persisting tokens to secure storage...');
      if (accessToken != null) {
        await _secure.write(key: 'access_token', value: accessToken);
        print('Access token written to storage');
      } else {
        await _secure.delete(key: 'access_token');
        print('Access token deleted from storage');
      }
      if (refreshToken != null) {
        await _secure.write(key: 'refresh_token', value: refreshToken);
        print('Refresh token written to storage');
      } else {
        await _secure.delete(key: 'refresh_token');
        print('Refresh token deleted from storage');
      }
      _keyringLocked = false;
      notifyListeners();
    } on PlatformException catch (e) {
      print('PlatformException while persisting tokens: ${e.code} - ${e.message}');
      _keyringLocked = true;
      throw KeyringLockedException(e.message);
    } catch (e) {
      // other storage errors -> clear in-memory to be safe
      print('Error persisting tokens to storage: $e');
      _accessToken = null;
      _refreshToken = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    // Attempt to notify backend to revoke the refresh token. Send the
    // `refreshToken` field in the request body as required by the API.
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      try {
        final dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
        // Protect against hanging network calls by applying a short timeout.
        await dio
            .post(
          ApiConfig.logoutPath,
          data: {'refreshToken': _refreshToken},
          options: Options(validateStatus: (status) => true),
        )
            .timeout(const Duration(seconds: 5));
        print('Remote logout request sent');
      } catch (e) {
        print('Logout remote call failed or timed out: $e');
      }
    }

    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _username = null;
    _isAdmin = false;
    try {
      await _secure.delete(key: 'access_token');
      await _secure.delete(key: 'refresh_token');
    } catch (_) {}
    notifyListeners();
  }

  void setCurrentUserProfile({String? id, String? username, bool? isAdmin}) {
    var changed = false;
    if (id != null && id.isNotEmpty && _userId != id) {
      _userId = id;
      changed = true;
    }
    if (username != null && username.isNotEmpty && _username != username) {
      _username = username;
      changed = true;
    }
    if (isAdmin != null && _isAdmin != isAdmin) {
      _isAdmin = isAdmin;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _trySetUserFromJwt(String? token) {
    if (token == null || token.isEmpty) return;
    final parts = token.split('.');
    if (parts.length < 2) return;
    try {
      final payload = _decodeJwtPart(parts[1]);
      if (payload is! Map) return;
      final userId = payload['user_id']?.toString() ??
          payload['id']?.toString() ??
          payload['sub']?.toString();
      final rawAdmin =
          payload['is_admin'] ?? payload['isAdmin'] ?? payload['admin'];
      final admin = _parseBool(rawAdmin);
      if (userId != null || rawAdmin != null) {
        setCurrentUserProfile(id: userId, isAdmin: rawAdmin == null ? null : admin);
      }
    } catch (_) {
      // ignore jwt parse errors
    }
  }

  dynamic _decodeJwtPart(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 2:
        normalized += '==';
      case 3:
        normalized += '=';
    }
    final bytes = base64Url.decode(normalized);
    return json.decode(utf8.decode(bytes));
  }

  bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  // Login with username or email + password. Accepts either snake_case or camelCase token fields.
  Future<bool> login(String usernameOrEmail, String password) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
      final String identifier = usernameOrEmail.trim();
      final bool isEmail = identifier.contains('@');
      
      final Map<String, dynamic> payload = {
        if (isEmail) 'email': identifier else 'username': identifier,
        'password': password,
      };
      
      print('Logging in with ${isEmail ? 'email' : 'username'}: $identifier');
      final resp = await dio.post(
        ApiConfig.loginPath,
        data: payload,
        options: Options(validateStatus: (status) => true),
      );
      
      final status = resp.statusCode ?? 0;
      final data = resp.data;
      print('Login status: $status');
      print('Login response: $data');

      String? access;
      String? refresh;
      String? userId;
      bool? isAdmin;

      if (data is Map) {
        access = (data['access_token'] ?? data['accessToken'])?.toString();
        refresh = (data['refresh_token'] ?? data['refreshToken'])?.toString();

        // Extract user info from response
        userId = data['user_id']?.toString() ??
            data['userId']?.toString() ??
            data['id']?.toString();
        final rawAdmin = data['is_admin'] ?? data['isAdmin'] ?? data['admin'];
        isAdmin = _parseBool(rawAdmin);
      }

      if (access != null && access.isNotEmpty && (status >= 200 && status < 300)) {
        try {
          await persistTokens(accessToken: access, refreshToken: refresh);
          print('Login successful, tokens persisted');
        } catch (storageError) {
          print('Login successful but storage failed: $storageError');
        }
        if (userId != null || isAdmin != null) {
          setCurrentUserProfile(id: userId, isAdmin: isAdmin);
        }
        _trySetUserFromJwt(access);
        return true;
      }
      print('Login failed: status=$status, no access token in response');
      return false;
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        print('Login error: DioException status=$status, body=${e.response?.data}');
      } else {
        print('Login error: $e');
      }
      return false;
    }
  }

  // Register new user with email, username, and password.
  Future<bool> register(String email, String username, String password) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
      
      final Map<String, dynamic> payload = {
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
      };
      
      print('Registering user: $username');
      final resp = await dio.post(
        ApiConfig.registerPath,
        data: payload,
        options: Options(validateStatus: (status) => true),
      );
      
      final status = resp.statusCode ?? 0;
      final data = resp.data;
      print('Register status: $status');
      print('Register response: $data');

      // Return true if registration was successful (typically 201 or 200)
      if (status >= 200 && status < 300) {
        // Optionally auto-login after registration
        // For now, just return success
        print('Registration successful');
        return true;
      }
      print('Registration failed: status=$status');
      return false;
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        print('Register error: DioException status=$status, body=${e.response?.data}');
      } else {
        print('Register error: $e');
      }
      return false;
    }
  }

  // Login with Google and exchange the ID token with the backend for app tokens.
  Future<bool> loginWithGoogle() async {
    try {
      String? idToken;
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        // Use Firebase Auth popup sign-in on web
        final provider = GoogleAuthProvider();
        final userCredential = await auth.signInWithPopup(provider);
        final user = userCredential.user;
        if (user == null) return false;
        idToken = await user.getIdToken();
      } else {
        // On mobile, use google_sign_in to obtain credentials then sign into Firebase
        final googleSignIn = FirebaseEnv.webClientId.isNotEmpty
            ? GoogleSignIn(
                scopes: ['email', 'profile'],
                serverClientId: FirebaseEnv.webClientId,
              )
            : GoogleSignIn(scopes: ['email', 'profile']);
        final account = await googleSignIn.signIn();
        if (account == null) {
          print('Google sign-in cancelled by user');
          return false;
        }
        final googleAuth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) return false;
        idToken = await user.getIdToken();
      }

      if (idToken == null || idToken.isEmpty) {
        print('Firebase Google sign-in did not return an ID token');
        return false;
      }

      print('Successfully obtained Firebase ID token, sending to backend...');
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
      final resp = await dio.post(
        ApiConfig.googlePath,
        data: {'idToken': idToken},
        options: Options(validateStatus: (status) => true),
      );

      final status = resp.statusCode ?? 0;
      final data = resp.data;
      print('Google login status: $status');
      print('Google login response: $data');

      String? access;
      String? refresh;

      if (data is Map) {
        access = (data['access_token'] ?? data['accessToken'])?.toString();
        refresh = (data['refresh_token'] ?? data['refreshToken'])?.toString();
      }

      if (access != null && access.isNotEmpty && (status >= 200 && status < 300)) {
        try {
          await persistTokens(accessToken: access, refreshToken: refresh);
          print('Google login successful, tokens persisted');
        } catch (storageError) {
          print('Google login successful but storage failed: $storageError');
        }
        _trySetUserFromJwt(access);
        return true;
      }

      print('Google login failed: status=$status');
      return false;
    } catch (e) {
      print('Google login error: $e');
      return false;
    }
  }

  

  // Refresh access token using refresh token. Returns true if refresh succeeded.
  Future<bool> refresh() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      print('Refresh failed: no refresh token available');
      return false;
    }
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
      print('Attempting token refresh...');
      final resp = await dio.post(
        ApiConfig.refreshPath,
        data: {'refresh_token': _refreshToken},
        options: Options(validateStatus: (status) => true),
      );
      final status = resp.statusCode ?? 0;
      final data = resp.data;
      print('Refresh status: $status');
      print('Refresh response: $data');
      
      String? access;
      String? refreshTok;

      if (data is Map) {
        access = data['access_token'];
        refreshTok = data['refresh_token'];
      }

      if (access != null && access.isNotEmpty && (status >= 200 && status < 300)) {
        try {
          await persistTokens(
            accessToken: access,
            refreshToken: refreshTok ?? _refreshToken,
          );
          print('Token refresh successful');
        } catch (storageError) {
          print('Token refresh successful but storage failed: $storageError');
        }
        return true;
      }
      print('Refresh failed: status=$status, no access token in response');
      await logout();
      return false;
    } catch (e) {
      print('Refresh error: $e');
      await logout();
      return false;
    }
  }
}
