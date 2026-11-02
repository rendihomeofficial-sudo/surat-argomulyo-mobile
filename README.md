# Surat Argomulyo - Aplikasi Android (Flutter)

Aplikasi Resmi Persuratan & Administrasi Desa Kampung Argomulyo, Kecamatan Banjit, Kabupaten Way Kanan.

## 📱 Fitur Aplikasi
- **Sidebar Navigation Drawer (Material 3):**
  - Surat Umum (SKU, SKCK, SKTM, Domisili, Kematian, dll.)
  - Kependudukan & Dukcapil (Biodata KK, Pindah, Kelahiran)
  - Formulir Nikah (NA N1 - N7)
  - Surat Keterangan Bersih Diri (SKBD)
  - Verifikasi TTE BSrE (Pemindai QR Code)
  - Portal Beranda
- **Identitas Lembaga:** Logo resmi Pemkab Way Kanan & Splash screen hijau gradasi emas.
- **Konfirmasi Keluar:** Dialog konfirmasi saat menekan tombol back Android.
- **Auto-Progress Bar:** Indikator pemuatan halaman halus.

## 🚀 Build Otomatis dengan GitHub Actions
Proyek ini sudah dilengkapi dengan alur kerja **GitHub Actions** (`.github/workflows/build_apk.yml`). Setiap kali kode di-push ke GitHub, APK Release akan otomatis di-build di cloud server GitHub dan siap diunduh di tab **Actions -> Artifacts**.
