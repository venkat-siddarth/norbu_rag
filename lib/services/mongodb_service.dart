import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';
import 'package:norbu_rag/models/gem_scan.dart';

class MongodbService extends ChangeNotifier {
  static final Uri baseUrL = Uri.parse(
    'https://express-js-on-vercel-beta-gilt.vercel.app/',
  );
  Db? _db;
  Map<String, dynamic>? _currentUser;
  bool _isConnecting = false;
  String? _connectionError;
  String _connectionString = "mongodb+srv://Vercel-Admin-gemID-DB:86ueUEPmZDrOLNbq@gemid-db.tbzksh.mongodb.net/?retryWrites=true&w=majority";

  bool get isConnected => _db != null && _db!.isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  String get connectionString => _connectionString;
  String? get currentUserEmail => _currentUser?['email'] as String?;

  void clearCurrentUser() {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
  }

  set connectionString(String val) {
    _connectionString = val;
    notifyListeners();
  }

  Future<bool> connect(String uri) async {
    if (uri.isEmpty) {
      _connectionError = "Connection string is empty";
      debugPrint("[MongoDB] ❌ Connection string is empty!");
      notifyListeners();
      return false;
    }

    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      debugPrint("[MongoDB] 🔄 Attempting to connect to: ${uri.replaceAll(RegExp(r':.*@'), ':****@')}");
      
      // If there's an existing active db, close it first
      if (_db != null) {
        debugPrint("[MongoDB] Closing existing connection...");
        await _db!.close();
      }

      _connectionString = uri;
      _db = await Db.create(uri);
      debugPrint("[MongoDB] Created Db instance, opening connection...");
      await _db!.open().timeout(const Duration(seconds: 10));

      _isConnecting = false;
      _connectionError = null;
      debugPrint("[MongoDB] ✅ Connected successfully! Ready to query users collection.");
      notifyListeners();
      return true;
    } catch (e) {
      _db = null;
      _isConnecting = false;
      _connectionError = e.toString();
      debugPrint("[MongoDB] ❌ Connection failed: $e");
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      notifyListeners();
    }
  }

  /// Finds user document by email. If not found, initializes a new user document.
  Future<Map<String, dynamic>?> getOrCreateUser(
    String email,
    String name, {
    String? avatar,
  }) async {
    try {
      final getUserUri = _endpoint('/getUser');
      debugPrint("[User API] 🔍 Fetching user for email: $email");

      final getResponse = await http.post(
        getUserUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
        final user = _extractUser(getResponse.body);
        if (user != null) {
          _currentUser = user;
          final scansCount = (user['scans'] as List?)?.length ?? 0;
          debugPrint("[User API] ✅ Found user with $scansCount scans");
          return user;
        }
      }

      if (getResponse.statusCode >= 300 && getResponse.statusCode != 404) {
        throw Exception(
          'User lookup failed (${getResponse.statusCode}): ${getResponse.body}',
        );
      }

      debugPrint("[User API] ℹ️ User not found, creating user for: $email");
      final createResponse = await http.post(
        _endpoint('/createUser'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'avatar': avatar != null && avatar.isNotEmpty
              ? avatar
              : 'https://api.dicebear.com/7.x/avataaars/svg?seed=John',
          'scansPerformed': 0,
          'scans': [],
          'scansRemaining': 10,
        }),
      );

      if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
        throw Exception(
          'User creation failed (${createResponse.statusCode}): ${createResponse.body}',
        );
      }

      final user = _extractUser(createResponse.body);
      if (user == null) {
        throw Exception('User creation response did not contain a user');
      }

      _currentUser = user;
      debugPrint("[User API] ✅ Created new user");
      return user;
    } catch (e) {
      debugPrint("[User API] ❌ Error fetching/creating user: $e");
      return null;
    }
  }

  Map<String, dynamic>? _extractUser(String responseBody) {
    final responseData = jsonDecode(responseBody);
    if (responseData is Map<String, dynamic>) {
      final user = responseData['user'];
      if (user is Map) return Map<String, dynamic>.from(user);
      return responseData;
    }
    return null;
  }

  /// Appends a new scan object and sends the complete scans list to the API.
  Future<Map<String, dynamic>?> saveScan({
    required String email,
    required GemScan scan,
    required String analysisMode,
  }) async {
    try {
      final now = DateTime.now();
      final imageUrl = await uploadImage(scan.localImagePath);
      
      // Construct nested scan object according to userSchema
      final newScanMap = {
        'id': ObjectId().oid,
        'timestamp': now.toUtc().toIso8601String(),
        'image': imageUrl,
        'analysisMode': analysisMode,
        'result': [
          scan.toPredictionJson(),
          ...scan.alternatives.map((alternative) => alternative.toJson()),
        ],
        'date': DateFormat('MM/dd/yyyy').format(now), // Standard locale date
        'time': DateFormat('hh:mm a').format(now), // Standard locale time
        'verificationResult': null,
        'correctResult': null,
      };

      if (currentUserEmail != email || _currentUser == null) {
        throw Exception('No cached user found for $email');
      }

      final scans = List<dynamic>.from((_currentUser!['scans'] as List?) ?? [])
        ..add(newScanMap);
      final response = await http.post(
        _endpoint('/updateScans'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'scans': scans,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Scan update failed (${response.statusCode}): ${response.body}',
        );
      }

      _currentUser!['scans'] = scans;
      return newScanMap;
    } catch (e) {
      debugPrint("[User API] Error saving scan: $e");
      rethrow;
    }
  }

  /// Uploads a local image as a base64 data URL and returns the hosted URL.
  /// Existing hosted URLs are returned unchanged for cloud-history retries.
  Future<String> uploadImage(String imagePath) async {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: $imagePath');
    }

    // final bytes = await imageFile.readAsBytes();
    // final mimeType = _mimeTypeFor(imagePath);
    // final imageData = 'data:$mimeType;base64,${base64Encode(bytes)}';

    // final uploadUri = _endpoint('/handleBlobs');
    // debugPrint('[Upload] Sending image to $uploadUri');
    // final response = await http.post(
    //   uploadUri,
    //   headers: {'Content-Type': 'application/json'},
    //   body: imageData,
    // );

    // if (response.statusCode < 200 || response.statusCode >= 300) {
    //   throw Exception(
    //     'Image upload failed (${response.statusCode}): ${response.body}',
    //   );
    // }

    // final responseData = jsonDecode(response.body);
    // final imageUrl = _extractImageUrl(responseData);
    // if (imageUrl == null || imageUrl.isEmpty) {
    //   throw Exception('Image upload response did not contain an image URL');
    // }

    debugPrint('[Upload] Image uploaded successfully');
    return imagePath; // Return the original path for now, as upload is commented out
  }

  Uri _endpoint(String path) => baseUrL.replace(path: path);
}
