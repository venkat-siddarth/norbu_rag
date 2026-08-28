import 'dart:async';
import 'package:flutter/material.dart';
import 'package:norbu_rag/screens/home_screen.dart';
import 'package:norbu_rag/screens/history_screen.dart';
import 'package:norbu_rag/screens/profile_screen.dart';
import 'package:norbu_rag/services/auth_service.dart';
import 'package:norbu_rag/services/history_service.dart';
import 'package:norbu_rag/services/gem_analysis_service.dart';
import 'package:norbu_rag/services/mongodb_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global Service instances
  final AuthService _authService = AuthService();
  final HistoryService _historyService = HistoryService();
  final GemAnalysisService _analysisService = GemAnalysisService();
  final MongodbService _mongodbService = MongodbService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Norbu RAG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo.shade700,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: MainNavigationScreen(
        authService: _authService,
        historyService: _historyService,
        analysisService: _analysisService,
        mongodbService: _mongodbService,
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final AuthService authService;
  final HistoryService historyService;
  final GemAnalysisService analysisService;
  final MongodbService mongodbService;

  const MainNavigationScreen({
    super.key,
    required this.authService,
    required this.historyService,
    required this.analysisService,
    required this.mongodbService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _lastSyncedEmail;
  bool _isSyncing = false;
  bool _wasConnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_syncHistoryIfNeeded);
    widget.mongodbService.addListener(_syncHistoryIfNeeded);
    
    _attemptConnectionAndSetupRetry();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_syncHistoryIfNeeded);
    widget.mongodbService.removeListener(_syncHistoryIfNeeded);
    _reconnectTimer?.cancel();
    super.dispose();
  }

  Future<void> _attemptConnectionAndSetupRetry() async {
    final mongo = widget.mongodbService;
    if (!mongo.isConnected && !mongo.isConnecting) {
      debugPrint("[DB] Attempting initial connection to MongoDB...");
      final success = await mongo.connect(mongo.connectionString).catchError((err) {
        debugPrint("[DB] ❌ Auto-connect to MongoDB failed: $err");
        return false;
      });
      
      if (success) {
        debugPrint("[DB] ✅ MongoDB connected successfully!");
        _showConnectionToast(true);
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      } else {
        debugPrint("[DB] ⚠️ Initial connection failed, setting up retry timer (30 min intervals)");
        _showConnectionToast(false);
        _startReconnectTimer();
      }
    } else if (mongo.isConnecting) {
      debugPrint("[DB] MongoDB connection already in progress...");
    } else if (mongo.isConnected) {
      debugPrint("[DB] MongoDB already connected");
      _showConnectionToast(true);
    }
  }

  void _showConnectionToast(bool isConnected) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isConnected 
                  ? "✅ Database connected" 
                  : "❌ Database connection failed",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
        duration: Duration(seconds: isConnected ? 2 : 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startReconnectTimer() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    debugPrint("[DB] 🔄 Setting up reconnect timer: will retry connection every 30 minutes.");
    _reconnectTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _retryConnection();
    });
  }

  Future<void> _retryConnection() async {
    final mongo = widget.mongodbService;
    if (!mongo.isConnected && !mongo.isConnecting) {
      debugPrint("[DB] 🔄 Retrying database connection (30-min interval)...");
      final success = await mongo.connect(mongo.connectionString).catchError((err) {
        debugPrint("[DB] ❌ Retry connection failed: $err");
        return false;
      });
      
      if (success) {
        debugPrint("[DB] ✅ Database reconnected successfully!");
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    } else if (mongo.isConnected) {
      debugPrint("[DB] MongoDB already connected, canceling retry timer");
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  Future<void> _syncHistoryIfNeeded() async {
    final auth = widget.authService;
    final mongo = widget.mongodbService;

    if (auth.isLoggedIn) {
      final email = auth.currentUser!.email;
      final connectionStatusChanged = !_wasConnected;
      _wasConnected = true;

      debugPrint("[SYNC] ════════════════════════════════════════");
      debugPrint("[SYNC] Auth: LoggedIn=${auth.isLoggedIn}, Email=$email");
      debugPrint("[SYNC] MongoDB: Connected=${mongo.isConnected}");
      debugPrint("[SYNC] LastEmail=$_lastSyncedEmail, ConnectionChanged=$connectionStatusChanged");
      debugPrint("[SYNC] PendingScans: ${widget.historyService.pendingScans.length}");

      // Sync if email changed, if we just reconnected, or if there are pending offline scans
      if ((_lastSyncedEmail != email || connectionStatusChanged || widget.historyService.pendingScans.isNotEmpty) && !_isSyncing) {
        _isSyncing = true;
        try {
          final name = auth.currentUser!.name;
          final avatar = auth.currentUser!.photoUrl;
          debugPrint("[SYNC] 🔄 Starting history sync for $email...");
          
          // Fetch and cache the user before replaying pending scans.
          debugPrint("[SYNC] 🔍 Querying user API for: $email");
          final userDoc = await mongo.getOrCreateUser(
            email,
            name,
            avatar: avatar,
          );

          if (userDoc != null && widget.historyService.pendingScans.isNotEmpty) {
            debugPrint("[SYNC] Found ${widget.historyService.pendingScans.length} pending offline scans. Syncing...");
            await widget.historyService.syncPendingScans(mongo, email);
          }
          
          if (userDoc != null) {
            final scans = (userDoc['scans'] as List?) ?? [];
            debugPrint("[SYNC] 📊 User document returned: ${scans.length} scans found");
            
            if (scans.isNotEmpty) {
              debugPrint("[SYNC] Starting to sync ${scans.length} scans from MongoDB...");
              widget.historyService.syncFromMongoScans(scans);
              _lastSyncedEmail = email;
              debugPrint("[SYNC] ✅ Successfully synced ${scans.length} scans");
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "✅ Synced ${scans.length} gem scans",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else {
              debugPrint("[SYNC] ℹ️ User has no scans yet");
            }
          } else {
            debugPrint("[SYNC] ⚠️ User document returned null");
          }
        } catch (e) {
          debugPrint("[SYNC] ❌ Auto-sync failed: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "❌ Sync failed: $e",
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          _isSyncing = false;
          debugPrint("[SYNC] ════════════════════════════════════════");
        }
      } else if (_isSyncing) {
        debugPrint("[SYNC] ⏳ Sync already in progress, skipping...");
      } else {
        debugPrint("[SYNC] ℹ️ Sync not needed - no changes detected");
        debugPrint("[SYNC] ════════════════════════════════════════");
      }
    } else {
      if (!mongo.isConnected) {
        debugPrint("[SYNC] ❌ MongoDB not connected. IsConnecting=${mongo.isConnecting}");
        if (mongo.connectionError != null) {
          debugPrint("[SYNC] Error: ${mongo.connectionError}");
        }
        _wasConnected = false;
      }
      if (!auth.isLoggedIn) {
        mongo.clearCurrentUser();
        debugPrint("[SYNC] ⚠️ User not logged in. Resetting to mock history.");
        if (_lastSyncedEmail != null) {
          widget.historyService.resetToMocks();
          _lastSyncedEmail = null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We listen to auth changes so that individual screens rebuild if login state changes
    return ListenableBuilder(
      listenable: Listenable.merge([widget.authService, widget.mongodbService]),
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                analysisService: widget.analysisService,
                historyService: widget.historyService,
                authService: widget.authService,
                mongodbService: widget.mongodbService,
              ),
              HistoryScreen(
                historyService: widget.historyService,
                mongodbService: widget.mongodbService,
                authService: widget.authService,
              ),
              ProfileScreen(
                authService: widget.authService,
                analysisService: widget.analysisService,
                historyService: widget.historyService,
                mongodbService: widget.mongodbService,
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
