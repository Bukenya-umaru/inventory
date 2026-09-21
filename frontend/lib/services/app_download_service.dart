import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_service.dart';

class AppRelease {
  final bool available;
  final String? versionName;
  final int? versionCode;
  final String? notes;
  final String? apkPath;
  final int? apkSizeBytes;

  const AppRelease({
    required this.available,
    this.versionName,
    this.versionCode,
    this.notes,
    this.apkPath,
    this.apkSizeBytes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        available: json['available'] == true,
        versionName: json['versionName']?.toString(),
        versionCode: json['versionCode'] is int
            ? json['versionCode'] as int
            : int.tryParse('${json['versionCode']}'),
        notes: json['notes']?.toString(),
        apkPath: json['apkPath']?.toString(),
        apkSizeBytes: json['apkSizeBytes'] is int
            ? json['apkSizeBytes'] as int
            : int.tryParse('${json['apkSizeBytes']}'),
      );
}

class AppDownloadService {
  /// Release info from the backend, or null if unavailable/offline.
  static Future<AppRelease?> fetchRelease() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/app/release'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final release = AppRelease.fromJson(
        (body['release'] as Map<String, dynamic>?) ?? const {},
      );
      return release.available ? release : null;
    } catch (_) {
      return null;
    }
  }

  /// Direct download URL for the APK (uses release metadata when available).
  static Future<String?> apkUrl() async {
    final release = await fetchRelease();
    if (release?.apkPath != null) {
      return '${ApiService.serverUrl}${release!.apkPath}';
    }
    // Fallback: conventional file name served by the backend.
    final fallback = '${ApiService.serverUrl}/downloads/app-release.apk';
    try {
      final res = await http.head(Uri.parse(fallback)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) return fallback;
    } catch (_) {}
    return null;
  }

  /// Opens the store/link on web; downloads the APK on Android and hands it
  /// to the system share sheet so the user gets the install prompt.
  /// Returns null when the download failed or the platform can't sideload.
  static Future<String?> downloadApk({void Function(int received, int total)? onProgress}) async {
    if (kIsWeb) {
      // On web, just navigate the browser tab to the APK URL — the browser
      // handles the download.
      final url = await apkUrl();
      return url == null ? null : 'WEB_OPEN:$url';
    }

    if (!Platform.isAndroid) {
      // iOS can't sideload APKs — caller shows the store link instead.
      return null;
    }

    try {
      final url = await apkUrl();
      if (url == null) return null;

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      if (response.statusCode != 200) return null;

      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        builder.add(chunk);
        onProgress?.call(builder.length, total);
      }
      final bytes = builder.takeBytes();

      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/inventory-app.apk');
      await file.writeAsBytes(bytes, flush: true);

      // Hand the APK to the system so the user gets the install prompt.
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Install the Inventory app'),
      );
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
