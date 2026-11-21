# Rancangan Git Account CLI

## Nama aplikasi

Nama aplikasi adalah **Git Account CLI**. Nama executable dan perintah di terminal adalah `git-account`. Setelah executable tersedia di `PATH`, Git juga dapat menemukannya sebagai subperintah `git account`. Dokumentasi dan keluaran bantuan menggunakan bentuk `git-account` secara konsisten.

## Ringkasan

`git-account` adalah CLI native Swift untuk membantu memakai akun Git yang tepat pada setiap repository. Pengguna menyimpan beberapa profil, lalu menerapkan profil ke repository aktif. CLI mengatur identitas commit dan konfigurasi SSH lokal repository tersebut.

Solusi ini tidak menyimpan password, token, atau isi private key. Credential tetap dikelola oleh SSH agent/Keychain atau credential manager yang sudah digunakan pengguna.

## Sasaran

- Mengurangi push dengan akun yang keliru ketika pengguna memiliki beberapa akun Git.
- Mengatur nama dan email commit per repository.
- Memilih SSH key per repository tanpa mengubah konfigurasi global.
- Memperlihatkan konfigurasi aktif dan menjelaskan masalah umum.
- Melindungi konfigurasi Git lain yang sudah dimiliki pengguna.

## Batasan MVP

- macOS, Swift Package Manager, dan Swift 5.9 atau lebih baru.
- Repository Git lokal dengan remote SSH.
- Profil menyimpan nama, email, dan path ke private key.
- Perubahan ditulis ke konfigurasi lokal repository (`.git/config`).
- Pengguna menjalankan `git-account use` secara eksplisit di dalam repository.
- `use` mengatur identitas author commit sekaligus key autentikasi SSH; keduanya ditampilkan terpisah pada `status` karena merupakan hal yang berbeda.

### Di luar cakupan MVP

- Menyimpan atau mengelola password/token HTTPS.
- Mengganti akun secara otomatis saat berpindah folder.
- Mengubah konfigurasi organisasi GitHub/GitLab atau membuat SSH key.
- GUI dan MCP server. MCP dapat ditambahkan kemudian sebagai adapter ke layanan inti yang sama.

## Perilaku pengguna

```text
git-account profile add pribadi \
  --name "Nama Saya" \
  --email "saya@example.com" \
  --ssh-key ~/.ssh/id_ed25519_pribadi

git-account profile add kantor \
  --name "Nama Kerja" \
  --email "saya@kantor.example" \
  --ssh-key ~/.ssh/id_ed25519_kantor

cd ~/src/proyek-kantor
git-account use kantor
git-account status
git-account profile list
```

Perintah `use` menetapkan `user.name`, `user.email`, dan `core.sshCommand` pada konfigurasi lokal repository. Bentuk `core.sshCommand` yang diterapkan:

```text
/usr/bin/ssh -i '/path/ke/key' -o IdentitiesOnly=yes -S none -o PreferredAuthentications=publickey
```

Normalisasi path key menjadi path absolut. Karena Git menjalankan `core.sshCommand` melalui shell, enkode path sebagai satu argumen shell POSIX, termasuk untuk spasi dan apostrof. Tolak karakter kontrol dan sintaks ekspansi OpenSSH pada path yang belum didukung oleh implementasi. OpenSSH menggunakan key ber-passphrase melalui agent, Keychain, atau prompt SSH yang tersedia. CLI sendiri tidak menangani passphrase.

## Bantuan dan antarmuka perintah

Keluaran CLI versi awal menggunakan bahasa Inggris. Contoh keluaran `git-account --help` berikut menetapkan isi bantuan utama.

```text
OVERVIEW: Manage Git commit identity and SSH keys per repository.

USAGE: git-account <subcommand>

OPTIONS:
  -h, --help              Show help.
  --version               Show the application version.

SUBCOMMANDS:
  profile                 Create, view, and remove saved profiles.
  use                     Apply a profile to the current repository.
  status                  Show the current repository's Git and SSH settings.
  doctor                  Diagnose local Git and SSH settings.
  unbind                  Remove the profile binding from the current repository.

Run 'git-account <subcommand> --help' for details and examples.
```

`-h` dan `--help` berlaku di tingkat utama, grup `profile`, dan setiap subperintah. Menjalankan `git-account` atau `git-account profile` tanpa subperintah menampilkan bantuan pada tingkat tersebut. `--version` berlaku di tingkat utama dan mencetak versi rilis dalam format SemVer, misalnya `0.1.0`. Bantuan dan versi dapat ditampilkan dari direktori mana pun, termasuk saat Git belum tersedia.

Setiap halaman bantuan menampilkan ringkasan, sintaks, argumen, opsi, dan satu contoh. Bantuan untuk grup `profile` juga mencantumkan semua subperintahnya. Tabel berikut menetapkan sintaks dan perilaku untuk tiap halaman.

| Sintaks setelah `git-account` | Perilaku dan isi bantuan | Contoh |
| --- | --- | --- |
| `profile` | Kelompok perintah untuk membuat, melihat, dan menghapus profil. | `git-account profile list` |
| `profile add <id> --name <name> --email <email> --ssh-key <path> [--replace]` | Simpan profil. Opsi nama, email, dan key wajib diisi. Gunakan `--replace` untuk memperbarui ID yang sudah ada. Jalankan kembali `use` di repo terkait untuk menerapkan perubahan profil. | `git-account profile add kantor --name "Nama Kerja" --email saya@kantor.example --ssh-key ~/.ssh/id_ed25519_kantor` |
| `profile list` | Tampilkan ID, nama, dan email profil dalam urutan ID. Penyimpanan kosong menampilkan cara membuat profil pertama. | `git-account profile list` |
| `profile show <id>` | Tampilkan ID, nama, email, path key, dan keberadaan file key. | `git-account profile show kantor` |
| `profile remove <id>` | Hapus profil dari penyimpanan CLI. Untuk melepas profil yang sudah diterapkan di repo, jalankan `unbind` di repo tersebut. | `git-account profile remove kantor` |
| `use <id> [--yes]` | Tampilkan rencana perubahan lalu minta konfirmasi. `--yes` melewati prompt dan cocok untuk pemakaian tanpa terminal interaktif. | `git-account use kantor` |
| `status` | Tampilkan repo, remote, identitas commit, konfigurasi SSH efektif, serta status profil. Repo tanpa profil tetap dapat diperiksa. | `git-account status` |
| `doctor` | Periksa Git, repo, remote, file key, dan SSH agent secara lokal. Laporkan temuan beserta langkah perbaikan. Pemeriksaan ini belum memverifikasi akses ke server. | `git-account doctor` |
| `unbind` | Lepas profil sesuai aturan pemulihan. Jika repo belum memiliki binding, tampilkan pesan bahwa tidak ada yang perlu dilepas. | `git-account unbind` |

Perintah `profile` berlaku dari direktori mana pun. `use`, `status`, `doctor`, dan `unbind` berlaku dari root repo atau subdirektorinya. ID profil memakai huruf kecil ASCII, angka, dan tanda hubung, serta diawali huruf atau angka. `--name` dan `--email` menerima nilai yang tidak kosong. `--ssh-key` menerima path absolut, path dengan awalan `~/`, atau path relatif terhadap direktori saat `profile add` dijalankan. Simpan hasilnya sebagai path absolut.

Contoh keluaran `git-account use --help`.

```text
OVERVIEW: Apply a saved profile to the current repository.

USAGE: git-account use <id> [--yes]

ARGUMENTS:
  <id>                    Saved profile ID. Run 'git-account profile list' to see IDs.

OPTIONS:
  --yes                   Apply without an interactive prompt.
  -h, --help              Show help.

EXAMPLE:
  git-account use kantor
```

### Keluaran dan kode keluar

| Kode | Arti |
| --- | --- |
| `0` | Berhasil, menampilkan bantuan atau versi, atau `unbind` selesai karena tidak ada binding. |
| `1` | Operasi gagal atau `doctor` menemukan masalah yang menghalangi pemakaian. |
| `2` | Sintaks salah, subperintah atau opsi tidak dikenal, atau argumen wajib kurang. |

Kirim hasil, bantuan, dan versi ke stdout. Kirim pesan kesalahan dan prompt ke stderr. Untuk kesalahan sintaks, sertakan perintah bantuan yang sesuai. Jika `use` dibatalkan pengguna, laporkan bahwa konfigurasi belum ditulis dan keluar dengan kode `0`. Jika input tidak interaktif dan `--yes` tidak diberikan, keluar dengan kode `1` dan jelaskan cara menjalankannya kembali. Ringkas konfigurasi SSH buatan pengguna dan samarkan credential apa pun dalam URL remote atau pesan kesalahan.

## Aturan pemilihan akun

Pada MVP, pemilihan akun bersifat eksplisit: pengguna menjalankan `git-account use <id>` di dalam repository. Ini menghindari perubahan konfigurasi global dan membuat hasilnya dapat diperiksa melalui `git config --local`.

Sebelum menulis, validasi semua URL efektif fetch dan push milik `origin` melalui `git remote get-url --all origin` dan `git remote get-url --push --all origin`. Git memperhitungkan aturan penulisan ulang URL pada kedua perintah ini. Wajib ada `origin` dan semua URL-nya harus memakai SSH, baik bentuk `ssh://` maupun bentuk SCP seperti `git@host:org/repo.git`. Perlakukan HTTPS, path lokal, dan skema lain sebagai tidak didukung untuk `origin`. Pertahankan URL remote dan aturan penulisan ulang yang sudah ada. [Dokumentasi Git remote](https://git-scm.com/docs/git-remote).

Satu repo memakai satu profil untuk semua remote SSH. Validasi konfigurasi SSH efektif untuk setiap tujuan SSH yang ditemukan. Tampilkan remote lain beserta cakupan pengaturan tersebut pada pratinjau dan `status`. Pada repo dengan beberapa worktree, konfigurasi lokal dibagikan. Tampilkan cakupan itu sebelum penulisan dan periksa konflik konfigurasi khusus worktree. Jika ada konflik yang membuat hasil berbeda antar worktree, batalkan `use` dengan petunjuk perbaikan. [Dokumentasi Git worktree](https://git-scm.com/docs/git-worktree).

`status` membaca nilai efektif untuk `user.name`, `user.email`, dan `core.sshCommand`, serta asal konfigurasi (`--show-origin`). Profil yang aktif ditentukan melalui marker lokal `git-account.profile`; jika marker tidak ada atau nilai Git tidak cocok lagi dengan snapshot konfigurasi yang dipasang CLI, tampilkan konfigurasi aktual dan status “manual/berbeda”, jangan menebak profil.

### Pemeriksaan sebelum switch

- Periksa konfigurasi efektif untuk setiap tujuan SSH dengan `ssh -G`, memakai opsi yang sama seperti saat Git terhubung. Pertahankan alias host dan pengaturan koneksi pengguna. `IdentitiesOnly=yes` masih mengizinkan beberapa `IdentityFile` dari konfigurasi SSH. Jika ada identitas tambahan yang berbeda atau sertifikat eksplisit yang belum didukung, batalkan switch dan jelaskan sumber konflik. Gunakan `-S none` agar Git tidak memakai ulang koneksi SSH yang sudah login dengan profil lain. [Dokumentasi OpenSSH client](https://man.openbsd.org/ssh), [Dokumentasi konfigurasi OpenSSH](https://man.openbsd.org/ssh_config).
- Periksa override yang terlihat saat perintah berjalan, termasuk `GIT_SSH_COMMAND`, varian SSH yang tidak kompatibel, konfigurasi Git yang lebih tinggi prioritasnya, dan variabel identitas author atau committer. Gunakan `git var GIT_AUTHOR_IDENT` dan `git var GIT_COMMITTER_IDENT` untuk membaca identitas commit yang efektif. Jika hasilnya bertentangan dengan profil, `use` gagal dengan petunjuk perbaikan dan `status` melaporkan override. Ini berlaku untuk environment yang diperiksa. Pemanggilan Git berikutnya bisa memakai environment atau opsi berbeda. [Dokumentasi konfigurasi Git](https://git-scm.com/docs/git-config), [Dokumentasi Git var](https://git-scm.com/docs/git-var).
- Keberhasilan `use` berarti konfigurasi lokal telah diterapkan dan pemeriksaan efektif lolos. `doctor` memeriksa konfigurasi dan agent secara lokal. Hak akses ke repo atau izin push hanya bisa dibuktikan melalui operasi terhadap server terkait.

## Penyimpanan data

Data profil disimpan sebagai JSON di:

```text
~/Library/Application Support/git-account/profiles.json
```

Contoh struktur:

```json
{
  "version": 1,
  "profiles": {
    "kantor": {
      "name": "Nama Kerja",
      "email": "saya@kantor.example",
      "sshKeyPath": "/Users/me/.ssh/id_ed25519_kantor"
    }
  }
}
```

File konfigurasi hanya menyimpan metadata dan path key. Buat direktori dengan permission privat bila memungkinkan, tulis file secara atomik, validasi versi skema, dan jangan pernah menampilkan isi private key pada log atau error.

## Arsitektur Swift

Gunakan Swift Package Manager dengan satu executable target dan modul inti yang terpisah. Untuk ukuran MVP, keduanya boleh berada dalam satu Swift package:

```text
Sources/
  GitAccountCLI/
    GitAccountCommand.swift
    Commands/
      ProfileCommands.swift
      UseCommand.swift
      StatusCommand.swift
      DoctorCommand.swift
      UnbindCommand.swift
  GitAccountCore/
    Models/Profile.swift
    Services/ProfileStore.swift
    Services/RepositoryInspector.swift
    Services/GitConfigManager.swift
    Services/SSHKeyValidator.swift
    Support/ProcessRunner.swift
```

CLI layer bertanggung jawab atas argumen, output, dan exit code. Core layer menangani profil, validasi, dan operasi Git. `ProcessRunner` menjalankan binary `git`/`ssh` melalui `Foundation.Process` dengan argumen terpisah, bukan string shell. Ini menghindari interpolasi command shell dan memudahkan pengujian.

Gunakan Swift ArgumentParser untuk parsing command dan help, atau implementasikan parsing sederhana jika dependency eksternal ingin dihindari. Keputusan ini dapat ditetapkan saat implementasi; keduanya menghasilkan executable Swift native.

## Pengamanan dan pemulihan

- Jangan meminta atau menyimpan password, token, maupun passphrase key.
- Jangan menjalankan command melalui shell dengan interpolasi string.
- Validasi path key, tetapi jangan membaca atau mencetak konten key.
- Sebelum `use`, tampilkan target repository dan perubahan yang akan dilakukan; minta konfirmasi interaktif. `--yes` dapat meniadakan konfirmasi untuk automation.
- Jika nilai lokal yang akan ditulis sudah ada dan berbeda, tampilkan nilai asal dan minta konfirmasi; jangan mengganti konfigurasi lain secara diam-diam.
- Simpan marker `git-account.profile`, snapshot nilai terpasang, dan nilai lokal asli beserta penanda jika sebelumnya absen. Simpan metadata di `git-account.managed.*`. Pertahankan nilai asli saat berpindah antarprofil. Jika ada perubahan manual setelah switch, `use` melaporkan konflik dan meminta pengguna menjalankan `unbind` sebelum menerapkan profil lagi. Switch ke profil yang sama dengan nilai efektif yang sama selesai tanpa menulis ulang.
- Saat `unbind`, pulihkan nilai lokal asli jika nilai saat ini masih cocok dengan snapshot terpasang. Hapus nilai lokal jika awalnya absen. Pertahankan perubahan manual dan laporkan setiap key yang dilewati. Hapus metadata binding setelah pemulihan. Pemulihan tetap bisa dilakukan setelah profil dihapus atau diperbarui.
- Siapkan nilai Git dan seluruh metadata dalam satu salinan konfigurasi yang diedit melalui parser Git. Publikasikan dalam satu penggantian atomik dengan protokol lock Git, termasuk pemeriksaan ulang bahwa file sumber belum berubah setelah pratinjau. Pertahankan izin file dan konfigurasi lain. Jika file terkunci, nilainya berubah, atau penulisan gagal sebelum publikasi, batalkan tanpa mengubah konfigurasi yang aktif. Gunakan mekanisme publikasi yang sama untuk `unbind`.
- Gunakan hanya key metadata lokal yang didokumentasikan: `git-account.profile` dan `git-account.managed.*`. Jangan menimpa key `git-account.*` yang tak dikenal.
- Error dan log tidak boleh memuat token, key material, atau environment sensitif.

## Kriteria penerimaan MVP

1. Pengguna dapat membuat, melihat, dan menghapus profil.
2. `use` di repository Git SSH mengatur nama/email lokal serta SSH key lokal.
3. Repository lain dan konfigurasi global tidak berubah.
4. `status` menunjukkan konfigurasi efektif serta perbedaan dari profil.
5. Remote HTTPS, profil tidak ada, repo bukan Git, dan key tidak ditemukan menghasilkan error yang jelas tanpa perubahan parsial.
6. `unbind` memulihkan nilai lokal awal, menghapus nilai yang awalnya absen, dan membiarkan perubahan manual pengguna.
7. Private key dan credential tidak pernah dibaca sebagai teks atau ditulis ke storage CLI.
8. Path key yang mengandung spasi dipakai dengan benar, dan nilai konfigurasi sebelumnya dipulihkan bila penerapan gagal.
9. Bantuan utama, grup `profile`, dan semua subperintah mencantumkan sintaks dan opsi yang sesuai. Bantuan dan versi berjalan di luar repo. Argumen yang salah menampilkan petunjuk bantuan dan kode keluar yang ditetapkan.
10. Matriks otomatis dan skenario dengan dua akun SSH di bagian Rencana pengujian lulus sebelum rilis.

## Rencana pengujian

Gunakan XCTest melalui `swift test` di macOS. Pisahkan tes unit untuk logika inti dari tes integrasi yang menjalankan executable CLI bersama Git dan OpenSSH. Jalankan keduanya tanpa akses jaringan. Buat direktori sementara per kasus dengan penyimpanan profil, konfigurasi Git, dan konfigurasi SSH khusus tes. Gunakan proses tiruan untuk kegagalan I/O yang perlu dipicu secara presisi. Gunakan binary Git dan OpenSSH sungguhan untuk perilaku yang bergantung pada cara keduanya membaca konfigurasi.

### Matriks tes otomatis

| ID | Tingkat | Skenario | Hasil yang diharapkan |
| --- | --- | --- | --- |
| T01 | Unit | Buat dua profil, muat ulang, coba simpan ID yang sama, ulangi dengan `--replace`, lalu hapus satu profil. | Profil tersimpan terpisah. Pembaruan ID perlu `--replace` dan penghapusan hanya mengenai profil yang dipilih. |
| T02 | Unit | Baca JSON rusak atau versi skema yang tidak didukung. Simulasikan kegagalan penulisan profil. | Error menyebut penyebab. File asal tetap bisa dipulihkan dan kegagalan penulisan tidak mengganti isi profil yang valid. |
| T03 | Integrasi | Jalankan bantuan utama, bantuan grup dan tiap subperintah, `--version`, serta argumen yang salah dari luar repo. | Bantuan dan versi ke stdout dengan kode `0`. Kesalahan sintaks ke stderr dengan kode `2` dan petunjuk bantuan. |
| T04 | Integrasi | Terapkan profil berbeda di dua repo sementara, termasuk menjalankan `use` dari subdirektori. Ulangi `use` dengan profil yang sama. | Tiap repo memakai profilnya sendiri. Config global dan remote tetap sama. Pengulangan profil yang sama tidak menulis ulang config. |
| T05 | Integrasi | Coba repo tanpa `origin`, direktori non-Git, ID yang tidak ada, key hilang, serta penggunaan tanpa terminal interaktif dan tanpa `--yes`. | Kode `1`, pesan perbaikan, dan config repo tetap sama. Pembatalan eksplisit di terminal interaktif menghasilkan kode `0` tanpa perubahan. |
| T06 | Integrasi | Uji remote SSH, remote HTTPS, URL yang diubah oleh aturan Git, dan dua URL push dengan salah satunya HTTPS. | CLI memvalidasi semua URL efektif. `use` menolak `origin` dengan URL non-SSH sebelum penulisan. Credential dalam URL disamarkan pada output. |
| T07 | Integrasi | Uji path key yang berisi spasi dan apostrof. Amati argumen yang sampai ke proses SSH tiruan. | Path diterima sebagai satu argumen dengan nilai persis seperti path asli. |
| T08 | Integrasi | Siapkan `IdentityFile` tambahan, `GIT_SSH_COMMAND`, override author atau committer, dan konfigurasi khusus worktree yang bertentangan. | `use` menjelaskan konflik dan berhenti tanpa perubahan. `status` menampilkan pengaturan efektif dan override yang relevan. |
| T09 | Integrasi | Siapkan konfigurasi SSH dengan `ControlMaster` dan `ControlPath`. Periksa hasil `ssh -G` untuk command yang dipasang CLI. | Opsi `-S none` menonaktifkan penggunaan ulang socket koneksi. Tes dengan koneksi yang benar-benar aktif dilakukan pada skenario rilis. |
| T10 | Integrasi | Tahan lock Git, ubah config setelah pratinjau, atau simulasikan kegagalan publikasi. | CLI gagal dengan pesan yang sesuai. Nilai Git dan metadata binding tidak terpasang sebagian. Perubahan dari proses lain tetap utuh. |
| T11 | Integrasi | Terapkan A, pindah ke B, hapus profil B, ubah salah satu key config secara manual, lalu jalankan `unbind` dua kali. | `unbind` memulihkan nilai lokal asli yang masih dikelola, menghapus nilai yang awalnya absen, dan mempertahankan perubahan manual. Pemanggilan kedua selesai dengan kode `0`. |
| T12 | Integrasi | Jalankan `doctor` untuk konfigurasi yang valid dan untuk beberapa masalah yang dapat diperbaiki, misalnya key hilang dan SSH agent tidak tersedia. | Laporan menjelaskan temuan dan tindakan perbaikan. Kode `1` dipakai untuk masalah yang menghalangi penggunaan. CLI tidak melaporkan bahwa akses server sudah terverifikasi. |

### Skenario rilis dengan dua akun SSH

Siapkan dua akun A dan B dengan key berbeda pada host Git yang sama. Sediakan repo uji untuk masing-masing akun dan satu repo yang mengizinkan keduanya. Gunakan remote dan branch khusus pengujian.

1. Terapkan A di repo pertama dan B di repo kedua. Pindah direktori beberapa kali dan jalankan `git-account status` serta `git fetch origin` tanpa menerapkan ulang profil. Pastikan setiap repo tetap memakai profilnya.
2. Di repo yang mengizinkan kedua akun, terapkan A, lalu B, lalu A lagi dengan `git-account use <id> --yes`. Pada setiap tahap, buat commit uji dan periksa author serta committer dengan `git log -1 --format='%an <%ae> / %cn <%ce>'`. Jalankan fetch dan push ke branch uji yang berbeda untuk setiap tahap.
3. Pertahankan koneksi SSH bersama milik A selama switch ke B. Untuk setiap tahap, cocokkan akun atau fingerprint key yang diterima server melalui audit server atau diagnostik autentikasi SSH. Push yang berhasil saja belum cukup karena kedua akun punya akses ke repo yang sama.
4. Di repo yang hanya mengizinkan A, terapkan B dan coba fetch. Fetch harus ditolak oleh server. Terapkan kembali A dan pastikan fetch berhasil. Jalankan `unbind` dan cocokkan nilai lokal dengan kondisi sebelum profil pertama diterapkan.

Catat hasil per kasus dengan status **Lulus**, **Gagal**, atau **Belum diuji**. Sertakan versi macOS, Git, OpenSSH, dan build CLI, serta kode keluar dan bukti yang relevan. Gunakan identitas uji dan samarkan credential dari log. Rilis MVP mensyaratkan semua tes otomatis dan skenario dengan dua akun lulus.

## Tahapan implementasi

1. Buat Swift Package dan model profil dengan Codable.
2. Implementasikan `ProfileStore` dengan penyimpanan atomik dan validasi skema.
3. Implementasikan `ProcessRunner` serta pemeriksaan repository/remote.
4. Tambahkan perintah `profile add/list/show/remove`.
5. Tambahkan `use`, `status`, dan `unbind` dengan perubahan config lokal yang aman.
6. Tambahkan `doctor` dan dokumentasi instalasi. Implementasikan tes otomatis sesuai matriks dan jalankan skenario dengan dua akun sebelum rilis.
7. Siapkan distribusi awal melalui `swift build`/binary lokal; evaluasi Homebrew setelah interface CLI stabil.

## Arah lanjutan

Jika pemilihan manual terasa merepotkan, tambahkan binding direktori ke profil melalui konfigurasi `includeIf` Git atau file pemetaan milik CLI. Otomasi tersebut perlu dirancang sebagai fitur terpisah karena pemilihan berbasis direktori, symlink, dan nested repository dapat menimbulkan ambiguitas. MCP dapat menjadi adapter opsional yang memanggil operasi core yang sama, tanpa menyimpan credential sendiri.
