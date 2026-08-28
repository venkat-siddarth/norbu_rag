import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:norbu_rag/models/gem_scan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService extends ChangeNotifier {
  final List<GemScan> _scans = [];
  final List<GemScan> _pendingScans = [];

  List<GemScan> get pendingScans => List.unmodifiable(_pendingScans);

  List<GemScan> get scans => List.unmodifiable(_scans..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

  HistoryService() {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _loadMockHistory();
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final pendingStr = prefs.getString('pending_scans');
      if (pendingStr != null) {
        final List<dynamic> jsonList = jsonDecode(pendingStr);
        _pendingScans.clear();
        for (var item in jsonList) {
          final map = item as Map<String, dynamic>;
          final timestampStr = map['timestamp'] as String?;
          _pendingScans.add(GemScan.fromJson(
            map,
            localImagePath: map['localImagePath'] as String? ?? '',
            timestamp: timestampStr != null ? DateTime.parse(timestampStr) : null,
          ));
        }
      }
      
      final scansStr = prefs.getString('cached_scans');
      if (scansStr != null) {
        final List<dynamic> jsonList = jsonDecode(scansStr);
        if (jsonList.isNotEmpty) {
          _scans.clear();
          for (var item in jsonList) {
            final map = item as Map<String, dynamic>;
            final timestampStr = map['timestamp'] as String?;
            _scans.add(GemScan.fromJson(
              map,
              localImagePath: map['localImagePath'] as String? ?? '',
              timestamp: timestampStr != null ? DateTime.parse(timestampStr) : null,
            ));
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading history from shared_preferences: $e");
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = _pendingScans.map((s) => s.toJson()).toList();
      await prefs.setString('pending_scans', jsonEncode(pendingJson));
      final scansJson = _scans.map((s) => s.toJson()).toList();
      await prefs.setString('cached_scans', jsonEncode(scansJson));
    } catch (e) {
      debugPrint("Error saving history to shared_preferences: $e");
    }
  }

  void _loadMockHistory() {
    _scans.addAll([
      GemScan(
        name: 'Ruby',
        category: 'Corundum',
        hardness: '9.0',
        confidence: '95%',
        colors: ['Deep Red', 'Pink-Red', 'Pigeon Blood Red'],
        characteristics: [
          'Vitreous luster',
          'Hexagonal crystal system',
          'Often contains silk inclusions'
        ],
        uses: ['Primarily used in high-end jewelry and historically in ruby lasers.'],
        description: 'Ruby is a pink to blood-red colored gemstone, a variety of the mineral corundum. Other varieties of gem-quality corundum are called sapphires. Ruby is one of the traditional cardinal gems.',
        localImagePath: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
              alternatives: [
                GemPrediction(
                  name: 'Red Spinel',
                  confidence: '75%',
                  category: 'Spinel',
                  hardness: '8.0',
                  colors: ['Red', 'Pink-Red'],
                  characteristics: ['Vitreous luster', 'No cleavage', 'Often very clean'],
                  description: 'Red spinel is a beautiful gemstone that is often confused with ruby.',
                  uses: ['Jewelry, collector stones'],
                ),
              ],
      ),
      GemScan(
        name: 'Emerald',
        category: 'Beryl',
        hardness: '7.5 - 8.0',
        confidence: '88%',
        colors: ['Vibrant Green', 'Bluish Green'],
        characteristics: [
          'Often highly included (called "jardin")',
          'Hexagonal prisms',
          'Brittle, prone to cracking'
        ],
        uses: ['Highly popular gemstone for jewelry, ornamental carvings.'],
        description: 'Emerald is a gemstone and a variety of the mineral beryl colored green by trace amounts of chromium and sometimes vanadium. Beryl has a hardness of 7.5–8 on the Mohs scale.',
        localImagePath: '',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
              alternatives: [
                GemPrediction(
                  name: 'Green Tourmaline',
                  confidence: '70%',
                  category: 'Tourmaline',
                  hardness: '7.0-7.5',
                  colors: ['Green', 'Bluish-Green'],
                  characteristics: ['Often pleochroic', 'Prismatic crystals', 'Vitreous luster'],
                  description: 'Green tourmaline is a popular green gemstone known for its variety of hues.',
                  uses: ['Jewelry, collector specimens'],
                ),
                GemPrediction(
                  name: 'Green Sapphire',
                  confidence: '55%',
                  category: 'Corundum',
                  hardness: '9.0',
                  colors: ['Green', 'Yellowish-Green'],
                  characteristics: ['Hexagonal', 'Hard and durable', 'Often has inclusions'],
                  description: 'Green sapphire is a less common variety of corundum colored by iron and titanium.',
                  uses: ['Fine jewelry, collector stones'],
                ),
              ],
      ),
      GemScan(
        name: 'Amethyst',
        category: 'Quartz',
        hardness: '7.0',
        confidence: '97%',
        colors: ['Purple', 'Violet', 'Deep Purple'],
        characteristics: [
          'Color zoning is common',
          'Conchoidal fracture',
          'No cleavage'
        ],
        uses: ['Jewelry, decorative geodes, metaphysical collections.'],
        description: 'Amethyst is a violet variety of quartz. The name comes from the ancient Greek a- "not" and methystos "intoxicated", a reference to the belief that the stone protected its owner from drunkenness.',
        localImagePath: '',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        alternatives: [],
      ),
    ]);
  }

  void addScan(GemScan scan) {
    _scans.add(scan);
    _saveToPreferences();
    notifyListeners();
  }

  void clearHistory() {
    _scans.clear();
    _saveToPreferences();
    notifyListeners();
  }

  void syncFromMongoScans(List<dynamic> mongoScans) {
    _scans.clear();
    debugPrint("[HISTORY] ════════════════════════════════════════");
    debugPrint("[HISTORY] Starting to parse ${mongoScans.length} MongoDB scans...");
    
    int successCount = 0;
    int failureCount = 0;
    
    for (int i = 0; i < mongoScans.length; i++) {
      final item = mongoScans[i];
      try {
        debugPrint("[HISTORY] [${i+1}/${mongoScans.length}] Processing scan...");
        
        final resultData = item['result'];
        Map<String, dynamic> resultJson;
        
        debugPrint("[HISTORY] Result type: ${resultData.runtimeType}");
        
        if (resultData is List) {
          if (resultData.isNotEmpty) {
            resultJson = resultData.first as Map<String, dynamic>;
            debugPrint("[HISTORY] Extracted first item from result array");
          } else {
            debugPrint("[HISTORY] ⚠️ Result is empty array, skipping");
            failureCount++;
            continue;
          }
        } else if (resultData is Map) {
          resultJson = resultData as Map<String, dynamic>;
          debugPrint("[HISTORY] Result is a Map");
        } else {
          debugPrint("[HISTORY] ❌ Invalid result type: ${resultData.runtimeType}");
          failureCount++;
          continue;
        }

        final localImagePath = item['image'] as String? ?? '';
        final timestampStr = item['timestamp'] as String?;
        final timestamp = timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();
        
        final gemName = resultJson['name'] as String? ?? 'Unknown';
        final confidence = resultJson['confidence'] as String? ?? 'N/A';

        final scan = GemScan.fromJson(
          resultJson,
          localImagePath: localImagePath,
          timestamp: timestamp,
        );
        // Parse alternatives from result array (skip first item as it's the main prediction)
        final List<GemPrediction> alternatives = [];
        if (resultData is List && resultData.length > 1) {
          for (int j = 1; j < resultData.length; j++) {
            try {
              final altJson = resultData[j] as Map<String, dynamic>;
              final altPrediction = GemPrediction.fromJson(altJson);
              alternatives.add(altPrediction);
            } catch (e) {
              debugPrint("[HISTORY] ⚠️ Error parsing alternative $j: $e");
            }
          }
        }
        
        // Create scan with alternatives
        final scanWithAlternatives = GemScan(
          name: scan.name,
          characteristics: scan.characteristics,
          colors: scan.colors,
          description: scan.description,
          hardness: scan.hardness,
          uses: scan.uses,
          category: scan.category,
          confidence: scan.confidence,
          localImagePath: localImagePath,
          timestamp: timestamp,
          alternatives: alternatives,
        );
        
        _scans.add(scanWithAlternatives);
        successCount++;
        debugPrint("[HISTORY] ✅ [${i+1}/${mongoScans.length}] Loaded: $gemName (Confidence: $confidence, Alternatives: ${alternatives.length})");
      } catch (e, stackTrace) {
        failureCount++;
        debugPrint("[HISTORY] ❌ [${i+1}/${mongoScans.length}] Error parsing scan: $e");
        debugPrint("[HISTORY] Stack: $stackTrace");
      }
    }
    
    debugPrint("[HISTORY] Parse complete: $successCount ✅ loaded, $failureCount ❌ failed");
    debugPrint("[HISTORY] Total scans in history: ${_scans.length}");
    debugPrint("[HISTORY] ════════════════════════════════════════");
    
    _saveToPreferences();
    notifyListeners();
  }

  void resetToMocks() {
    _scans.clear();
    _pendingScans.clear();
    _loadMockHistory();
    _saveToPreferences();
    notifyListeners();
  }

  void markAsPendingSync(GemScan scan) {
    if (!_pendingScans.contains(scan)) {
      _pendingScans.add(scan);
      _saveToPreferences();
      notifyListeners();
    }
  }

  Future<void> syncPendingScans(dynamic mongoService, String email) async {
    final scansToSync = List<GemScan>.from(_pendingScans);
    for (var scan in scansToSync) {
      try {
        await mongoService.saveScan(
          email: email,
          scan: scan,
          analysisMode: 'offline-scan',
        );
        _pendingScans.remove(scan);
      } catch (e) {
        debugPrint("Failed to sync pending scan to MongoDB: $e");
      }
    }
    _saveToPreferences();
    notifyListeners();
  }
}

