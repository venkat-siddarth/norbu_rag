import 'dart:io';
import 'package:flutter/material.dart';
import 'package:norbu_rag/models/gem_scan.dart';
import 'package:norbu_rag/services/auth_service.dart';
import 'package:norbu_rag/services/gem_analysis_service.dart';
import 'package:norbu_rag/services/history_service.dart';
import 'package:norbu_rag/services/mongodb_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String imagePath;
  final GemAnalysisService analysisService;
  final HistoryService historyService;
  final AuthService authService;
  final MongodbService mongodbService;
  final VoidCallback onScanAnother;

  const AnalysisScreen({
    super.key,
    required this.imagePath,
    required this.analysisService,
    required this.historyService,
    required this.authService,
    required this.mongodbService,
    required this.onScanAnother,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isAnalyzing = false;
  GemScan? _result;
  String? _errorMessage;
  bool _isExhausted = false;
  bool _showScanAnotherButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Auto-trigger analysis when view loaded
    _analyzeImage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll > 0 && currentScroll >= maxScroll - 15) {
        if (!_showScanAnotherButton) {
          setState(() {
            _showScanAnotherButton = true;
          });
        }
      }
    }
  }

  void _checkScrollability() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (_scrollController.position.maxScrollExtent <= 0) {
          setState(() {
            _showScanAnotherButton = true;
          });
        }
      }
    });
  }

  Future<void> _analyzeImage() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _isExhausted = false;
      _result = null;
      _showScanAnotherButton = false;
    });

    try {
      final result = await widget.analysisService.analyzeGemImage(widget.imagePath);
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
      // Save scan to history
      widget.historyService.addScan(result);
      
      // Save to MongoDB database if user is signed in, otherwise fall back to local pending list
      if (widget.authService.isLoggedIn) {
        final email = widget.authService.currentUser!.email;
        try {
          final savedScan = await widget.mongodbService.saveScan(
            email: email,
            scan: result,
            analysisMode: 'api-identification',
          );
          debugPrint('[ANALYSIS] ✅ Saved scan to cloud: ${savedScan?['id']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Analysis saved to your cloud history'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (err) {
          debugPrint("Failed to sync scan to cloud, storing locally for retry: $err");
          widget.historyService.markAsPendingSync(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cloud save failed; queued for retry')),
            );
          }
        }
      }

      _checkScrollability();
    } on IdentificationQuotaExceededException catch (e) {
      setState(() {
        _isExhausted = true;
        _errorMessage = e.message;
        _isAnalyzing = false;
      });
      _checkScrollability();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
        _isAnalyzing = false;
      });
      _checkScrollability();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis Result"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Image Preview
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Loading State
                  if (_isAnalyzing)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.onSurface.withAlpha(20),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              "Analyzing Gem Features...",
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),

                  // Quota Exhausted State
                  if (_isExhausted)
                    Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "API Limit Exhausted",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage ?? "Daily limits exceeded.",
                              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _analyzeImage,
                              child: const Text("Retry Scan"),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // General Error State
                  if (!_isExhausted && _errorMessage != null)
                    Card(
                      color: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.orange.shade800, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Analysis Failed",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _analyzeImage,
                              child: const Text("Retry Scan"),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Prediction Result Info
                  if (_result != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _result!.name,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${_result!.confidence} Match",
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Chip(
                                  label: Text("Category: ${_result!.category}"),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text("Hardness: ${_result!.hardness}"),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            
                            // Colors
                            Text(
                              "Colors",
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _result!.colors.map((color) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(color, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Characteristics
                            Text(
                              "Characteristics",
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Column(
                              children: _result!.characteristics.map((char) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          char,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Description
                            Text(
                              "Description",
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _result!.description,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 16),

                            // Uses
                            Text(
                              "Primary Uses",
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Column(
                              children: _result!.uses.map((char) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          char,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                  ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: widget.onScanAnother,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text(
                        "Scan Another Gem",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
