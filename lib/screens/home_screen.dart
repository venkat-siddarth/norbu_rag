import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:norbu_rag/screens/analysis_screen.dart';
import 'package:norbu_rag/services/auth_service.dart';
import 'package:norbu_rag/services/gem_analysis_service.dart';
import 'package:norbu_rag/services/history_service.dart';
import 'package:norbu_rag/services/mongodb_service.dart';
import 'package:norbu_rag/services/update_service.dart';

class HomeScreen extends StatefulWidget {
  final GemAnalysisService analysisService;
  final HistoryService historyService;
  final AuthService authService;
  final MongodbService mongodbService;

  const HomeScreen({
    super.key,
    required this.analysisService,
    required this.historyService,
    required this.authService,
    required this.mongodbService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;
  const _DownloadProgressDialog({required this.apkUrl});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    await UpdateService.downloadAndInstall(
      widget.apkUrl,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading update...'),
      content: LinearProgressIndicator(value: _progress),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;
  
  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update == null || !mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Update available: v${update.version}'),
        content: Text(update.notes),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDownloadProgress(update.apkUrl);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDownloadProgress(String apkUrl) {
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(apkUrl: apkUrl),
    );
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }


  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85, // optimize image size
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error selecting image: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedImagePath != null) {
      return AnalysisScreen(
        imagePath: _selectedImagePath!,
        analysisService: widget.analysisService,
        historyService: widget.historyService,
        authService: widget.authService,
        mongodbService: widget.mongodbService,
        onScanAnother: () {
          setState(() {
            _selectedImagePath = null;
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Norbu RAG"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Banner & Focus Info
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.primary.withAlpha(50)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.camera_enhance, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Identify Your Gemstone",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Take a photo or upload an image. Camera mode uses native autofocus for precise scanning.",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Input Selector Column (Stacked Vertically)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 24),
                  label: const Text(
                    "Take Photo (Camera)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.cloud_upload, size: 24),
                  label: const Text(
                    "Upload Image",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
