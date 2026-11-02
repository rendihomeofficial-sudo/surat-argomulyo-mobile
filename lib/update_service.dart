import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String githubApiUrl =
      'https://api.github.com/repos/rendihomeofficial-sudo/surat-argomulyo-mobile/releases/latest';

  /// Memeriksa apakah ada rilis versi terbaru di GitHub
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'SuratArgomulyo-App'},
      ));

      final response = await dio.get(githubApiUrl);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        String tagName = data['tag_name'] ?? '';
        String latestVersion = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
        String body = data['body'] ?? 'Pembaruan sistem dan perbaikan fitur.';

        // Cari aset app-release.apk
        String downloadUrl = '';
        if (data['assets'] != null && data['assets'] is List) {
          for (var asset in data['assets']) {
            if (asset['name'] != null &&
                asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] ?? '';
              break;
            }
          }
        }

        if (downloadUrl.isEmpty) {
          downloadUrl =
              'https://github.com/rendihomeofficial-sudo/surat-argomulyo-mobile/releases/download/$tagName/app-release.apk';
        }

        bool hasUpdate = _isVersionGreater(latestVersion, currentVersion);

        return UpdateInfo(
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          hasUpdate: hasUpdate,
        );
      }
    } catch (e) {
      debugPrint('Check update error: $e');
    }
    return null;
  }

  /// Membandingkan nomor versi semver (misal 1.0.1 > 1.0.0)
  static bool _isVersionGreater(String newV, String oldV) {
    List<int> nParts =
        newV.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> oParts =
        oldV.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLen = nParts.length > oParts.length ? nParts.length : oParts.length;
    for (int i = 0; i < maxLen; i++) {
      int n = i < nParts.length ? nParts[i] : 0;
      int o = i < oParts.length ? oParts[i] : 0;
      if (n > o) return true;
      if (n < o) return false;
    }
    return false;
  }
}

/// Dialog Pop-up Update Modern & Halus
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  CancelToken? _cancelToken;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Mempersiapkan unduhan...';
      _errorMessage = null;
    });

    try {
      // 1. Cek izin instal paket di Android 8.0+
      if (Platform.isAndroid) {
        final installStatus = await Permission.requestInstallPackages.status;
        if (!installStatus.isGranted) {
          final res = await Permission.requestInstallPackages.request();
          if (!res.isGranted) {
            setState(() {
              _isDownloading = false;
              _errorMessage =
                  'Harap izinkan pemasangan aplikasi dari sumber ini pada pengaturan HP Anda.';
            });
            return;
          }
        }
      }

      // 2. Tentukan lokasi simpan APK di memori cache HP
      final dir = await getExternalStorageDirectory() ??
          await getTemporaryDirectory();
      final apkPath =
          '${dir.path}/surat_argomulyo_v${widget.updateInfo.latestVersion}.apk';

      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete(); // Hapus file lama jika ada agar bersih
      }

      // 3. Mulai unduh APK dengan Dio
      _cancelToken = CancelToken();
      final dio = Dio();

      await dio.download(
        widget.updateInfo.downloadUrl,
        apkPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _progress = received / total;
              final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _statusText = 'Mengunduh: $recMb MB / $totMb MB (${(_progress * 100).toInt()}%)';
            });
          }
        },
      );

      setState(() {
        _statusText = 'Unduhan selesai! Membuka paket pembaruan...';
      });

      // 4. Langsung pasang (Install) APK otomatis tanpa error
      final openRes = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      if (openRes.type != ResultType.done) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Gagal membuka installer otomatis: ${openRes.message}. Anda bisa membuka file di folder Download HP.';
        });
      } else {
        if (mounted) {
          Navigator.pop(context); // Tutup dialog jika installer sudah tampil
        }
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Gagal mengunduh pembaruan: $e';
      });
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Ikon & Versi
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF0F6B4F),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pembaruan Tersedia!',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Versi ${widget.updateInfo.latestVersion} (Versi Anda: ${widget.updateInfo.currentVersion})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F6B4F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Catatan Rilis
            const Text(
              'Apa yang baru di versi ini:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 110),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.releaseNotes.isEmpty
                      ? 'Pembaruan performa, perbaikan tata letak surat, dan stabilitas aplikasi desa.'
                      : widget.updateInfo.releaseNotes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Progress Bar saat mengunduh
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF0F6B4F)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F6B4F),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Tombol Aksi
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Nanti Saja',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F6B4F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: _isDownloading ? null : _startDownloadAndInstall,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _isDownloading ? 'Mengunduh...' : 'Perbarui Sekarang',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
