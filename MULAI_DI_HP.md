# Memulai FABLEBRINK lewat HP

Dokumen ini disiapkan untuk workflow Android + GitHub. Kamu tidak perlu PC untuk mengunggah source dan meminta GitHub Actions membuat APK.

## A. Masukkan source ke GitHub

1. Buat repository baru bernama `FABLEBRINK` di akun GitHub kamu.
2. Pilih repository **Public** agar kuota GitHub Actions untuk repository publik lebih sederhana. Jangan pernah menaruh password database atau secret hosting di source.
3. Ekstrak `FABLEBRINK.zip` di HP. Pastikan `project.godot` berada langsung di root folder repository, bukan di dalam folder bersarang dua kali.
4. Unggah isi folder ke repository. Di GitHub mobile/web, gunakan **Add file → Upload files**. Bila jumlah file terlalu banyak untuk sekali unggah, lakukan bertahap sambil menjaga susunan folder.
5. Pastikan `.github/workflows/` ikut terunggah. Folder bertitik kadang tidak terlihat di aplikasi pengelola berkas; aktifkan opsi tampilkan file tersembunyi.

## B. Minta GitHub membuat APK

1. Buka tab **Actions** di repository.
2. Pilih **Build FABLEBRINK Android APK**.
3. Tekan **Run workflow** pada branch `main`.
4. Tunggu proses selesai. Buka hasil workflow yang berstatus hijau.
5. Pada bagian **Artifacts**, unduh `FABLEBRINK-Android-debug`.
6. Ekstrak artifact tersebut untuk mendapatkan `FABLEBRINK-debug.apk`, lalu install di Android.

APK yang dihasilkan adalah debug-signed APK untuk pengujian. Workflow membuat kunci debug sementara di runner GitHub; kunci ini bukan kunci rilis permanen.

## C. Aktifkan multiplayer online

Game client tidak otomatis menjadi server. Buat database PostgreSQL dan deploy folder `server/` ke layanan hosting Node.js/WebSocket yang dapat diakses teman-teman melalui internet.

1. Sediakan connection string PostgreSQL sebagai environment variable `DATABASE_URL` pada hosting server.
2. Set `DATABASE_SSL=true` jika provider database mewajibkan TLS.
3. Deploy konfigurasi `render.yaml` sebagai Blueprint, atau deploy Dockerfile `server/Dockerfile` ke penyedia hosting lain yang mendukung WebSocket.
4. Buka `https://alamat-server/health`. Status yang diharapkan adalah `ok`.
5. Isi alamat WebSocket pada layar Login/Create Account di game: `wss://alamat-server/ws`.
6. Buat akun pada dua perangkat, lalu uji Host dan Join dari jaringan internet yang berbeda.

Jangan menaruh `DATABASE_URL` ke APK, ke `project.godot`, atau ke GitHub. Masukkan hanya pada bagian Environment/Secrets milik penyedia hosting.

## D. Catatan sebelum menguji

- Room maksimal lima pemain dan hanya menerima Join saat host masih berada di lobby.
- Setelah Start Game, room berubah menjadi `playing`; kode lama akan ditolak untuk pemain baru.
- Room berada di memori server. Jika server restart, room yang sedang berjalan akan berakhir.
- Akun tersimpan di PostgreSQL jika `DATABASE_URL` telah diatur. Mode JSON lokal hanya untuk pengembangan dan tidak cocok untuk hosting dengan filesystem sementara.
- Singleplayer disimpan lokal di perangkat. Belum ada cloud-save lintas perangkat.
- Multiplayer movement/block relay adalah prototipe, belum memiliki server-authoritative physics/anti-cheat.
