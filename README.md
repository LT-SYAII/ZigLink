# ⚡ ZigLink - Simple & Powerful URL Shortener

![ZigLink Banner](src/og-image.png)

**ZigLink** adalah solusi pemendek URL berperforma tinggi yang dirancang untuk kemudahan penggunaan dan privasi maksimal. Dibangun menggunakan **Zig**, aplikasi ini menawarkan kecepatan luar biasa dengan konsumsi sumber daya yang sangat rendah.

---

## ✨ Fitur Unggulan

*   **🚀 Performa Native**: Tidak menggunakan runtime (seperti Node.js/Python), berjalan langsung di atas mesin.
*   **🛡️ Keamanan Berlapis**: Dilengkapi dengan **Silent JS Challenge** untuk memblokir bot dan DDoS.
*   **🔗 Custom Alias**: Buat link sesuai brand Anda (contoh: `domain.com/diskon-spesial`).
*   **📱 QR Code Generator**: Otomatis membuat kode QR untuk setiap link yang dipendekkan.
*   **📑 Real-time History**: Pantau link yang baru dibuat melalui dashboard yang interaktif.
*   **📄 Database Persisten**: Data tersimpan aman dalam file JSON, tidak hilang saat restart.

---

## 🛠️ Panduan Instalasi (Step-by-Step)

Ikuti langkah-langkah di bawah ini untuk menjalankan ZigLink di server Linux (VPS) Anda sendiri.

### 1. Prasyarat Sistem
Pastikan server Anda sudah terinstall:
*   **Zig Compiler 0.12.0**
*   **Nginx**
*   **Certbot** (untuk HTTPS)

### 2. Persiapan Folder & Kode
```bash
git clone https://github.com/LT-SYAII/ZigLink.git
cd ZigLink
```

### 3. Kompilasi (Build)
Ubah kode sumber menjadi aplikasi executable yang dioptimasi:
```bash
# Build dalam mode ReleaseSafe untuk performa maksimal namun tetap aman
zig build -Doptimize=ReleaseSafe

# Pindahkan binary ke lokasi yang mudah diakses
mv zig-out/bin/zig zig-out/bin/ziglink
```

### 4. Konfigurasi Autostart (Systemd)
Agar aplikasi berjalan otomatis di background dan hidup kembali jika server restart:

1.  Buat file service: `sudo nano /etc/systemd/system/ziglink.service`
2.  Tempelkan kode berikut (sesuaikan path `/root/zig` dengan lokasi folder Anda):
    ```ini
    [Unit]
    Description=ZigLink URL Shortener
    After=network.target

    [Service]
    Type=simple
    User=root
    WorkingDirectory=/root/zig
    ExecStart=/root/zig/zig-out/bin/ziglink
    Restart=always

    [Install]
    WantedBy=multi-user.target
    ```
3.  Aktifkan service:
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable ziglink
    sudo systemctl start ziglink
    ```

### 5. Konfigurasi Nginx (Reverse Proxy)
Agar aplikasi bisa diakses melalui domain (port 80/443), bukan port 8081:

1.  Buat config baru: `sudo nano /etc/nginx/sites-available/ziglink`
2.  Tempelkan konfigurasi dasar:
    ```nginx
    server {
        server_name domain-anda.com;
        location / {
            proxy_pass http://127.0.0.1:8081;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
    ```
3.  Aktifkan dan restart Nginx:
    ```bash
    sudo ln -s /etc/nginx/sites-available/ziglink /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
    ```

### 6. Aktivasi HTTPS (SSL Gratis)
Gunakan Let's Encrypt agar website Anda memiliki gembok hijau:
```bash
sudo certbot --nginx -d domain-anda.com
```

---

## 📡 Dokumentasi API

### Shorten URL
*   **Endpoint**: `POST /api/shorten`
*   **Header**: `Content-Type: application/json`
*   **Body**:
    ```json
    {
      "url": "https://website-sangat-panjang.com/data/123",
      "alias": "link-keren"
    }
    ```

---

## 🛡️ Sistem Keamanan (Anti-Bot)
ZigLink menggunakan metode **Silent JS Challenge**. 
*   **Browser**: Pengguna asli tidak akan merasakan apa-apa, browser otomatis memverifikasi diri ke server.
*   **Bot/CLI (Curl)**: Jika mencoba memanggil API secara langsung tanpa browser, server akan merespon: `{"error": "you can't because you're robot!"}`.

---

## 👤 Author & Support

Dibuat dengan semangat oleh **Bang Syaii**.

*   ☕ **Donasi via Saweria**: [saweria.co/bgsyaii](https://saweria.co/bgsyaii)
*   🌐 **Portofolio**: [bang.syaii.sbs](https://bang.syaii.sbs)

---
*ZigLink © 2026. Merampingkan link, mempercepat koneksi.*
