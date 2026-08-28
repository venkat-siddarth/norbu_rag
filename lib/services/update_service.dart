// lib/services/update_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class UpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;

  UpdateInfo({required this.version, required this.apkUrl, required this.notes});
}

class UpdateService {
  static const _repo = 'yourname/yourrepo'; // <-- change this
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    final tagName = json['tag_name'] as String; // e.g. "v1.0.1"
    final latestVersion = tagName.replaceFirst('v', '');

    final assets = json['assets'] as List;
    final apkAsset = assets.firstWhere(
      (a) => (a['name'] as String).endsWith('.apk'),
      orElse: () => null,
    );
    if (apkAsset == null) return null;

    final currentInfo = await PackageInfo.fromPlatform();

    if (_isNewer(latestVersion, currentInfo.version)) {
      return UpdateInfo(
        version: latestVersion,
        apkUrl: apkAsset['browser_download_url'],
        notes: json['body'] ?? '',
      );
    }
    return null;
  }

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.parse).toList();
    final l = local.split('.').map(int.parse).toList();
    for (var i = 0; i < r.length; i++) {
      if (i >= l.length || r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstall(
    String apkUrl, {
    required void Function(double progress) onProgress,
  }) async {
    if (await Permission.requestInstallPackages.isDenied) {
      await Permission.requestInstallPackages.request();
    }

    final dir = await getExternalStorageDirectory();
    final savePath = '${dir!.path}/app-update.apk';
    final file = File(savePath);

    final request = http.Request('GET', Uri.parse(apkUrl));
    final response = await request.send();
    final total = response.contentLength ?? 0;
    int received = 0;

    final sink = file.openWrite();
    await response.stream.map((chunk) {
      received += chunk.length;
      if (total > 0) onProgress(received / total);
      return chunk;
    }).pipe(sink);
    await sink.close();

    await OpenFilex.open(savePath);
  }
}