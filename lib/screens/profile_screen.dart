import 'package:flutter/material.dart';
import 'package:norbu_rag/services/auth_service.dart';
import 'package:norbu_rag/services/gem_analysis_service.dart';
import 'package:norbu_rag/services/history_service.dart';
import 'package:norbu_rag/services/mongodb_service.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final GemAnalysisService analysisService;
  final HistoryService historyService;
  final MongodbService mongodbService;

  const ProfileScreen({
    super.key,
    required this.authService,
    required this.analysisService,
    required this.historyService,
    required this.mongodbService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: widget.analysisService.apiUrl);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  // Calculate stats
  String _getMostCommonGem(HistoryService history) {
    if (history.scans.isEmpty) return "None";
    final Map<String, int> counts = {};
    for (var scan in history.scans) {
      counts[scan.name] = (counts[scan.name] ?? 0) + 1;
    }
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authService,
        widget.analysisService,
        widget.historyService,
        widget.mongodbService,
      ]),
      builder: (context, _) {
        final auth = widget.authService;
        final analysis = widget.analysisService;
        final history = widget.historyService;

        // 1. Not Logged In - Show Mock Google Login Screen
        if (!auth.isLoggedIn) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Sign In"),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              centerTitle: true,
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.diamond_outlined,
                      size: 100,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Welcome to Norbu RAG",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Scan, identify, and catalog rare gemstones instantly. Log in with Google to sync your history across devices.",
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    if (auth.isLoading)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Connecting to Google OAuth account..."),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => auth.loginWithGoogle(),
                        icon: const Icon(Icons.login),
                        label: const Text("Sign In with Google"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // 2. Logged In State
        final user = auth.currentUser!;
        final totalScans = history.scans.length;
        final popularGem = _getMostCommonGem(history);

        return Scaffold(
          appBar: AppBar(
            title: const Text("User Profile"),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: NetworkImage(user.photoUrl),
                        backgroundColor: theme.colorScheme.primary.withAlpha(30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statistics Section
              Text(
                "Your Scan Statistics",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              "$totalScans",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text("Total Gems Scanned", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              popularGem,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text("Most Common Gem", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),



              Text(
                "Identification API",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "API endpoint",
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (val) => analysis.apiUrl = val,
              ),
              const SizedBox(height: 32),

              // Logout Button
              ElevatedButton.icon(
                onPressed: () => auth.logout(),
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    },
    );
  }

}
