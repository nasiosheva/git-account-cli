# Git Account CLI

Git Account CLI (`git-account`) adalah aplikasi command-line native Swift untuk
mengelola profil identitas Git dan SSH per repository. Rancangan lengkap tersedia
di [git-account-cli-design.md](git-account-cli-design.md).

> **Status: dalam pengembangan; MVP belum selesai.** Pengelolaan profil sudah
> tersedia, tetapi `use` belum menerapkan profil ke repository. Jangan
> mengandalkan aplikasi ini untuk memilih akun Git atau SSH saat ini.

## Persyaratan

- macOS
- Swift 5.9 atau lebih baru
- Git untuk pemeriksaan repository

## Build dan instalasi lokal

```sh
git clone https://github.com/nasiosheva/git-account-cli.git
cd git-account-cli
swift build -c release
```

Executable tersedia di `.build/release/git-account`. Jalankan langsung:

```sh
.build/release/git-account --help
```

Atau tambahkan direktori build ke `PATH` pada shell aktif:

```sh
export PATH="$PWD/.build/release:$PATH"
git-account --version
```

Setelah executable tersedia di `PATH`, Git juga dapat menemukannya sebagai
`git account`. Perubahan `PATH` di atas hanya berlaku untuk sesi shell aktif.

## Penggunaan yang tersedia

### Menambah profil

```sh
git-account profile add pribadi \
  --name "Nama Saya" \
  --email "saya@example.com" \
  --ssh-key ~/.ssh/id_ed25519_pribadi
```

ID profil terdiri dari huruf kecil ASCII, angka, dan tanda hubung; karakter
pertama harus huruf atau angka. Path key disimpan sebagai path absolut. Untuk
memperbarui ID yang sudah ada, tambahkan `--replace`. Membuat profil tidak
mengubah konfigurasi repository dan tidak memvalidasi akses SSH ke server.

### Melihat dan menghapus profil

```sh
git-account profile list
git-account profile show pribadi
git-account profile remove pribadi
```

`profile show` melaporkan apakah file key ada. Menghapus profil hanya menghapus
metadata dari penyimpanan aplikasi; file key tidak dihapus.

### Memeriksa repository

Jalankan dari dalam repository Git:

```sh
git-account status
git-account doctor
```

`status` saat ini menampilkan root repository, remote dengan rincian yang
disamarkan, asal konfigurasi identitas dan SSH, serta nama variabel override
yang terdeteksi. `doctor` memeriksa keberadaan `origin`, bentuk URL remote
efektif, dan keberadaan variabel SSH agent secara terbatas. Pemeriksaan ini
**belum lengkap** dan tidak memverifikasi akses server atau izin push.

## Fitur yang belum selesai

- `use` belum menerapkan identitas commit atau key SSH; perintah gagal tanpa
  mengubah konfigurasi Git.
- `unbind` hanya menangani repository tanpa binding. Pemulihan binding yang ada
  belum diimplementasikan dan gagal tanpa mengubah konfigurasi Git.
- `status` belum memverifikasi snapshot binding atau seluruh identitas dan
  override efektif.
- `doctor` belum mencakup seluruh pemeriksaan key, SSH, dan konfigurasi yang
  ditetapkan dalam rancangan.
- Pengamanan penulisan Git atomik, pemeriksaan worktree dan konflik SSH,
  matriks tes integrasi, serta skenario rilis dua akun masih harus diselesaikan.

Gunakan Git dan konfigurasi SSH yang sudah ada untuk mengatur akun hingga
fitur-fitur tersebut selesai dan telah diuji.

## Penyimpanan dan keamanan

Metadata profil disimpan di
`~/Library/Application Support/git-account/profiles.json`. Data ini mencakup
nama, email, dan path key, bukan isi private key. Aplikasi tidak meminta atau
menyimpan password, token, maupun passphrase.

## Pengujian

```sh
swift test
```

Tes yang tersedia saat ini adalah tes unit untuk penyimpanan profil, normalisasi
path, penyamaran remote, dan pemanggilan proses. Tes tersebut belum mencakup
seluruh matriks pengujian atau skenario rilis dalam dokumen rancangan.
