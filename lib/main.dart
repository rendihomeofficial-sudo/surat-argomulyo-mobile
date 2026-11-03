import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SuratArgomulyoApp());
}

class SuratArgomulyoApp extends StatelessWidget {
  const SuratArgomulyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surat Argomulyo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6B4F),
          primary: const Color(0xFF0F6B4F),
          secondary: const Color(0xFFB07D12),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F6B4F),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
      ),
      home: const MainPersuratanScreen(),
    );
  }
}

class MainPersuratanScreen extends StatefulWidget {
  const MainPersuratanScreen({super.key});

  @override
  State<MainPersuratanScreen> createState() => _MainPersuratanScreenState();
}

class _MainPersuratanScreenState extends State<MainPersuratanScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;
  String _currentTitle = 'Surat Umum';

  final Map<String, String> _menuUrls = {
    'Surat Umum': 'https://surat.argomulyo.com/surat.html',
    'Kependudukan & Dukcapil': 'https://surat.argomulyo.com/kependudukan.html',
    'Formulir Nikah (NA)': 'https://surat.argomulyo.com/na_pernikahan.html',
    'Surat Bersih Diri (SKBD)': 'https://surat.argomulyo.com/skbd.html',
    'Buku Tamu Pelayanan': 'https://surat.argomulyo.com/buku_tamu.html',
    'Portal Beranda': 'https://surat.argomulyo.com/index.html',
    'Verifikasi TTE (Scan QR)': 'https://surat.argomulyo.com/validasi.php',
  };

  @override
  void initState() {
    super.initState();
    _initWebViewController();

    // Otomatis periksa pembaruan versi APK di background setelah aplikasi terbuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  void _initWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 SuratArgomulyoApp/1.0',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
                if (progress >= 80) {
                  _isLoading = false;
                }
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _loadingProgress = 0;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _updateTitleFromUrl(url);
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebResourceError: ${error.description}');
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Tangkap berkas ekspor data (CSV / JSON) agar diunduh langsung & dibuka oleh aplikasi Office/Excel HP
            if (url.contains('action=export_agenda_csv') ||
                url.contains('action=export_buku_tamu_csv') ||
                url.endsWith('.csv') ||
                url.endsWith('.json')) {
              _downloadAndOpenExportFile(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Aktifkan pengaturan native Android yang optimal & bebas glitch
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setGeolocationEnabled(true);
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
      androidController.setOverScrollMode(WebViewOverScrollMode.never);
    }

    _controller = controller;
    _controller.loadRequest(Uri.parse('https://surat.argomulyo.com/surat.html'));
  }

  Widget _buildWebViewWidget() {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(
      controller: _controller.platform,
      layoutDirection: TextDirection.ltr,
    );
    // Matikan expensive Hybrid Composition agar rendering berjalan native dan tidak glitch/kedip
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        params,
        displayWithHybridComposition: false,
      );
    }
    return WebViewWidget.fromPlatformCreationParams(
      params: params,
    );
  }

  Future<void> _checkAutoUpdate({bool showNoUpdateToast = false}) async {
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (info != null && info.hasUpdate) {
        UpdateDialog.show(context, info);
      } else if (showNoUpdateToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplikasi Anda sudah menggunakan versi terbaru.'),
            backgroundColor: Color(0xFF0F6B4F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('AutoUpdate Error: $e');
    }
  }

  void _updateTitleFromUrl(String url) {
    final lower = url.toLowerCase();
    String detectedTitle = _currentTitle;

    if (lower.contains('kependudukan.html')) {
      detectedTitle = 'Kependudukan & Dukcapil';
    } else if (lower.contains('ktp.html')) {
      detectedTitle = 'Permohonan KTP';
    } else if (lower.contains('f101_biodata_kk.html')) {
      detectedTitle = 'F-1.01 Biodata KK';
    } else if (lower.contains('f103_pindah.html')) {
      detectedTitle = 'F-1.03 Pindah Penduduk';
    } else if (lower.contains('f205_kelahiran.html')) {
      detectedTitle = 'F-2.05 Kelahiran';
    } else if (lower.contains('f106_ubah_biodata.html')) {
      detectedTitle = 'F-1.06 Ubah Biodata';
    } else if (lower.contains('f228_kematian.html')) {
      detectedTitle = 'F-2.28 Kematian';
    } else if (lower.contains('na_pernikahan.html')) {
      detectedTitle = 'Formulir Nikah (NA)';
    } else if (lower.contains('skbd.html')) {
      detectedTitle = 'Surat Bersih Diri (SKBD)';
    } else if (lower.contains('buku_tamu.html')) {
      detectedTitle = 'Buku Tamu Pelayanan';
    } else if (lower.contains('validasi.php')) {
      detectedTitle = 'Verifikasi Dokumen TTE';
    } else if (lower.contains('index.html')) {
      detectedTitle = 'Portal Beranda';
    } else if (lower.contains('surat.html')) {
      detectedTitle = 'Surat Umum';
    }

    if (detectedTitle != _currentTitle) {
      setState(() {
        _currentTitle = detectedTitle;
      });
    }
  }

  Future<void> _downloadAndOpenExportFile(String downloadUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Sedang mengunduh berkas laporan...'),
            ],
          ),
          backgroundColor: Color(0xFF0F6B4F),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final dir = await getExternalStorageDirectory() ??
          await getTemporaryDirectory();

      String filename = 'LAPORAN_ARGOMULYO_${DateTime.now().millisecondsSinceEpoch}.csv';
      if (downloadUrl.contains('buku_tamu')) {
        filename = 'BUKU_TAMU_ARGOMULYO_${DateTime.now().millisecondsSinceEpoch}.csv';
      } else if (downloadUrl.contains('json')) {
        filename = 'BACKUP_ARGOMULYO_${DateTime.now().millisecondsSinceEpoch}.json';
      }

      final savePath = '${dir.path}/$filename';
      final dio = Dio();
      await dio.download(downloadUrl, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berkas berhasil diunduh: $filename'),
          backgroundColor: const Color(0xFF0F6B4F),
          action: SnackBarAction(
            label: 'Buka',
            textColor: const Color(0xFFFBBF24),
            onPressed: () {
              OpenFilex.open(savePath);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Otomatis buka file dengan aplikasi Excel / Text Viewer HP
      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('Export file download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh berkas laporan: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateTo(String title, String url) {
    setState(() {
      _currentTitle = title;
      _isLoading = true;
      _loadingProgress = 0;
      _errorMessage = null;
    });
    Navigator.pop(context); // Tutup drawer sidebar
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (!context.mounted) return;
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Keluar Aplikasi?'),
              content: const Text(
                  'Apakah Anda yakin ingin keluar dari aplikasi Persuratan Kampung Argomulyo?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6B4F)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Buka Menu Layanan',
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTitle,
                style:
                    const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Kampung Argomulyo – Way Kanan',
                style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
              tooltip: 'Segarkan Halaman',
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2.5),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
                    backgroundColor: const Color(0xFF0B5640),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                  ),
                )
              : null,
        ),
        drawer: _buildSidebarDrawer(),
        body: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // WebView Area Utama
              _buildWebViewWidget(),

              // Jika ada galat jaringan / koneksi putus
              if (_errorMessage != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 56,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Koneksi Internet Terganggu',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gagal memuat halaman: $_errorMessage\nPastikan HP Anda terhubung dengan internet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6B4F),
                          ),
                          onPressed: () => _controller.reload(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Indikator Loading Tipis Non-Blocking agar tidak menutupi layar menjadi blank/hitam
              if (_isLoading && _loadingProgress < 40)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6B4F).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Memuat data...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header Lembaga Resmi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F6B4F), Color(0xFF0B5640)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFB07D12), width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child:
                            Image.asset('assets/logo.png', width: 44, height: 44),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pemerintah Desa',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'KAMPUNG ARGOMULYO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Kec. Banjit, Way Kanan',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0x26FFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    border: Border.fromBorderSide(BorderSide(color: Colors.white24)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Color(0xFFFBBF24), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Portal Persuratan Resmi Digital',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Daftar Item Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionHeader('LAYANAN PERSURATAN'),
                _buildDrawerItem(
                  icon: Icons.description_rounded,
                  title: 'Surat Umum',
                  subtitle: 'SKU, SKCK, SKTM, Domisili, dll',
                  isSelected: _currentTitle == 'Surat Umum',
                  onTap: () =>
                      _navigateTo('Surat Umum', _menuUrls['Surat Umum']!),
                ),
                _buildDrawerItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Kependudukan & Dukcapil',
                  subtitle: 'Biodata KK, Pindah, Kelahiran',
                  isSelected: _currentTitle == 'Kependudukan & Dukcapil',
                  onTap: () => _navigateTo('Kependudukan & Dukcapil',
                      _menuUrls['Kependudukan & Dukcapil']!),
                ),
                _buildDrawerItem(
                  icon: Icons.favorite_rounded,
                  title: 'Formulir Nikah (NA)',
                  subtitle: 'Blangko N1 s/d N7 Resmi KUA',
                  isSelected: _currentTitle == 'Formulir Nikah (NA)',
                  onTap: () => _navigateTo(
                      'Formulir Nikah (NA)', _menuUrls['Formulir Nikah (NA)']!),
                ),
                _buildDrawerItem(
                  icon: Icons.security_rounded,
                  title: 'Surat Bersih Diri (SKBD)',
                  subtitle: 'Keterangan Bebas Kriminal/TNI/POLRI',
                  isSelected: _currentTitle == 'Surat Bersih Diri (SKBD)',
                  onTap: () => _navigateTo('Surat Bersih Diri (SKBD)',
                      _menuUrls['Surat Bersih Diri (SKBD)']!),
                ),
                _buildDrawerItem(
                  icon: Icons.menu_book_rounded,
                  title: 'Buku Tamu Pelayanan',
                  subtitle: 'Catat Tamu & Tanda Tangan Digital',
                  isSelected: _currentTitle == 'Buku Tamu Pelayanan',
                  onTap: () => _navigateTo('Buku Tamu Pelayanan',
                      _menuUrls['Buku Tamu Pelayanan']!),
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),
                _buildSectionHeader('VERIFIKASI & PORTAL'),
                _buildDrawerItem(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Verifikasi Dokumen TTE',
                  subtitle: 'Validasi Barcode Keaslian Surat',
                  isSelected: _currentTitle == 'Verifikasi TTE (Scan QR)',
                  onTap: () => _navigateTo('Verifikasi TTE (Scan QR)',
                      _menuUrls['Verifikasi TTE (Scan QR)']!),
                ),
                _buildDrawerItem(
                  icon: Icons.public_rounded,
                  title: 'Portal Beranda Desa',
                  subtitle: 'Menu Lengkap Layanan Administrasi',
                  isSelected: _currentTitle == 'Portal Beranda',
                  onTap: () => _navigateTo(
                      'Portal Beranda', _menuUrls['Portal Beranda']!),
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),
                _buildSectionHeader('SISTEM & INFORMASI'),
                _buildDrawerItem(
                  icon: Icons.system_update_rounded,
                  title: 'Periksa Pembaruan APK',
                  subtitle: 'Versi v1.0.7 (Rilis Resmi)',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    _checkAutoUpdate(showNoUpdateToast: true);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Aplikasi',
                  subtitle: 'Pemerintah Kampung Argomulyo',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutAppDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F6B4F)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : const Color(0xFF0F6B4F),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected
              ? const Color(0xFF0F6B4F)
              : const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFFECFDF5),
      dense: true,
      onTap: onTap,
    );
  }

  void _showAboutAppDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Color(0xFF0F6B4F)),
            SizedBox(width: 10),
            Text('Tentang Aplikasi', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aplikasi Resmi Persuratan & Kependudukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            SizedBox(height: 6),
            Text(
              'Pemerintah Kampung Argomulyo\nKecamatan Banjit, Kabupaten Way Kanan\nProvinsi Lampung',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            SizedBox(height: 12),
            Text(
              'Versi: 1.0.7 (Stabil & Super Ringan)',
              style: TextStyle(fontSize: 12, color: Color(0xFF0F6B4F), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F6B4F),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
