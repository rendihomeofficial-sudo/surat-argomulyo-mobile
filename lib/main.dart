import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6B4F),
          primary: const Color(0xFF0F6B4F),
          secondary: const Color(0xFFB07D12),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F6B4F),
          foregroundColor: Colors.white,
          elevation: 2,
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
  String _currentTitle = 'Surat Umum';

  // Daftar Menu Layanan
  final Map<String, String> _menuUrls = {
    'Surat Umum': 'https://surat.argomulyo.com/surat.html',
    'Kependudukan & Dukcapil': 'https://surat.argomulyo.com/kependudukan.html',
    'Formulir Nikah (NA)': 'https://surat.argomulyo.com/na_pernikahan.html',
    'Surat Bersih Diri (SKBD)': 'https://surat.argomulyo.com/skbd.html',
    'Portal Beranda': 'https://surat.argomulyo.com/index.html',
    'Verifikasi TTE (Scan QR)': 'https://surat.argomulyo.com/validasi.php',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4F6F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebResourceError: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://surat.argomulyo.com/surat.html'));

    // Otomatis periksa pembaruan versi APK di background setelah aplikasi terbuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  Future<void> _checkAutoUpdate({bool showNoUpdateToast = false}) async {
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
  }

  void _navigateTo(String title, String url) {
    setState(() {
      _currentTitle = title;
      _isLoading = true;
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
                  preferredSize: const Size.fromHeight(3.0),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: const Color(0xFF0B5640),
                    valueColor: const ColorAnimation(Color(0xFFFBBF24)),
                  ),
                )
              : null,
        ),
        drawer: _buildSidebarDrawer(),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && _loadingProgress < 60)
              Container(
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', width: 68, height: 68),
                      const SizedBox(height: 18),
                      const SpinKitThreeBounce(
                        color: Color(0xFF0F6B4F),
                        size: 28.0,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Memuat Layanan Surat...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F6B4F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child:
                          Image.asset('assets/logo.png', width: 44, height: 44),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KAMPUNG ARGOMULYO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kecamatan Banjit\nKabupaten Way Kanan',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11.5,
                              height: 1.2,
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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
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
                  icon: Icons.home_rounded,
                  title: 'Portal Beranda',
                  subtitle: 'Menu Utama Sistem Kampung',
                  isSelected: _currentTitle == 'Portal Beranda',
                  onTap: () =>
                      _navigateTo('Portal Beranda', _menuUrls['Portal Beranda']!),
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),
                _buildSectionHeader('PEMBARUAN & SISTEM'),
                _buildDrawerItem(
                  icon: Icons.system_update_rounded,
                  title: 'Periksa Pembaruan APK',
                  subtitle: 'Cek versi terbaru di cloud GitHub',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    _checkAutoUpdate(showNoUpdateToast: true);
                  },
                ),
              ],
            ),
          ),

          // Footer Versi Aplikasi
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text(
              'Versi 1.0.0 Resmi • Kampung Argomulyo',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F6B4F),
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
}

class ColorAnimation extends AlwaysStoppedAnimation<Color> {
  const ColorAnimation(super.value);
}
