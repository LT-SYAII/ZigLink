# ⚡ ZigLink - High Performance URL Shortener

ZigLink adalah aplikasi pemendek URL modern yang dibangun menggunakan bahasa pemrograman **Zig**. Aplikasi ini dirancang untuk kecepatan ekstrem, keamanan tinggi, dan penggunaan sumber daya yang sangat minim.

## 🔥 Fitur Utama

*   **Blazing Fast**: Dibangun dengan Zig (native code), tanpa runtime berat seperti Node.js atau Python.
*   **Secure**: Dilengkapi dengan **JS Challenge Anti-Bot** dan validasi URL ketat.
*   **Real-time Analytics**: Dashboard interaktif dengan grafik pertumbuhan link dan statistik sistem.
*   **Custom Alias**: Pengguna bisa membuat nama link sesuka hati.
*   **QR Code**: Generate QR code otomatis untuk setiap link.
*   **Persistent**: Database file JSON sederhana namun tangguh.
*   **Responsive UI**: Tampilan "Clean Modern" yang adaptif untuk Desktop dan Mobile.

## 🛠️ Teknologi

*   **Backend**: Zig (HTTP Server, JSON Parser, System Info)
*   **Frontend**: HTML5, CSS3 (Neo-Brutalism/Modern), JavaScript Vanilla
*   **Server**: Nginx (Reverse Proxy), Systemd (Service Management)

## 🚀 Cara Menjalankan

### Prasyarat
*   Compiler Zig (Versi 0.12.0 atau terbaru)
*   Linux Server (Ubuntu/Debian recommended)

### Instalasi & Build

1.  **Clone Repository**
    ```bash
    git clone https://github.com/username/ziglink.git
    cd ziglink
    ```

2.  **Build Project** (Mode Release untuk performa maksimal)
    ```bash
    zig build -Doptimize=ReleaseSafe
    ```

3.  **Jalankan Manual**
    ```bash
    ./zig-out/bin/ziglink
    ```
    Server akan berjalan di port `8081`.

### Deployment (Systemd)

Untuk menjalankan di background secara otomatis:

1.  Edit file service di `/etc/systemd/system/ziglink.service`.
2.  Aktifkan service:
    ```bash
    sudo systemctl enable ziglink
    sudo systemctl start ziglink
    ```

## 📡 Dokumentasi API

### 1. Shorten Link
Membuat link pendek baru.

*   **Endpoint**: `POST /api/shorten`
*   **Body (JSON)**:
    ```json
    {
      "url": "https://example.com/long-url",
      "alias": "custom-name" (Opsional)
    }
    ```
*   **Response**:
    ```json
    { "short_code": "custom-name" }
    ```

### 2. Server Info
Mengambil statistik server dan riwayat link.

*   **Endpoint**: `GET /info`
*   **Response**: JSON berisi statistik OS, RAM, dan daftar link.

## 👤 Author

Dibuat dengan ❤️ oleh **Bang Syaii**.

*   🌐 **Website**: [bang.syaii.sbs](https://bang.syaii.sbs)
*   ☕ **Support**: [Saweria](https://saweria.co/bgsyaii)

---
*ZigLink © 2026. Open Source Project.*
