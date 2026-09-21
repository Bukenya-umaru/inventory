import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_download_service.dart';
import '../utils/download_helper.dart';
import '../utils/theme.dart';

/// Floating action button that lets users download & install the mobile app.
/// - Web (phone browser): downloads the APK via the browser.
/// - Android: downloads the APK and opens the system install prompt.
/// - iOS: opens the App Store link (IOS_APP_URL) or explains it's coming soon.
class DownloadAppFab extends StatelessWidget {
  final bool mini;

  const DownloadAppFab({super.key, this.mini = true});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: mini,
      tooltip: 'Get the mobile app',
      onPressed: () => showAppDownloadSheet(context),
      child: const Icon(Icons.download_rounded),
    );
  }
}

/// Bottom sheet with the download options. Also opened from the settings menu.
Future<void> showAppDownloadSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => const _DownloadSheet(),
  );
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet();

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  AppRelease? _release;
  bool _loadingRelease = true;
  bool _downloading = false;
  int _received = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadRelease();
  }

  Future<void> _loadRelease() async {
    final release = await AppDownloadService.fetchRelease();
    if (mounted) setState(() { _release = release; _loadingRelease = false; });
  }

  String get _iosUrl => dotenv.maybeGet('IOS_APP_URL') ?? '';

  bool get _isIos => !kIsWeb && Platform.isIOS;

  Future<void> _download() async {
    setState(() { _downloading = true; _received = 0; _total = 0; });
    try {
      final url = await AppDownloadService.apkUrl();
      if (url == null) {
        _showError('No app release is available yet. Try again later.');
        return;
      }

      if (kIsWeb) {
        // Browser download: fetch the bytes and save via an anchor element.
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) {
          _showError('Could not download the app. Please try again.');
          return;
        }
        await downloadBytes(res.bodyBytes, 'inventory-app.apk',
            'application/vnd.android.package-archive');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('APK downloaded. Open it to install the app.')));
          Navigator.pop(context);
        }
        return;
      }

      // Android: stream to a file with progress, then open the installer
      // prompt through the system share sheet.
      final path = await AppDownloadService.downloadApk(
        onProgress: (received, total) {
          if (mounted) setState(() { _received = received; _total = total; });
        },
      );
      if (path == null) {
        _showError('Download failed. Check your connection and try again.');
        return;
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showError('Download failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _downloading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openIosStore() async {
    final uri = Uri.parse(_iosUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Could not open the App Store link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryText(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.phone_android_rounded,
                      color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Get the mobile app',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 17),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor(context))),
                      const SizedBox(height: 2),
                      Text(
                        _loadingRelease
                            ? 'Checking for the latest version…'
                            : (_release?.versionName != null
                                ? 'Version ${_release!.versionName}'
                                : 'Install on your phone for the best experience'),
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 12),
                          color: AppTheme.secondaryText(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isIos) ...[
              if (_iosUrl.isNotEmpty)
                _primaryButton(
                  label: 'Open the App Store',
                  icon: Icons.apple,
                  onPressed: _downloading ? null : _openIosStore,
                )
              else
                Text(
                  'The iOS app is coming soon. Please use the web app for now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context)),
                ),
            ] else ...[
              _primaryButton(
                label: _downloading ? 'Downloading…' : 'Download APK',
                icon: _downloading ? null : Icons.download_rounded,
                onPressed: _downloading ? null : _download,
              ),
              if (_downloading && _total > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null,
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_received / (1024 * 1024)).toStringAsFixed(1)} MB of ${(_total / (1024 * 1024)).toStringAsFixed(1)} MB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 12),
                    color: AppTheme.secondaryText(context)),
                ),
              ],
              if (!isDark) const SizedBox(height: 4),
              if (!kIsWeb && !_downloading)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'After downloading, allow "Install unknown apps" for your\nbrowser if Android asks for permission.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 11),
                      color: AppTheme.secondaryText(context)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, IconData? icon, VoidCallback? onPressed}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: 20)
            : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        label: Text(label,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 15),
              fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
