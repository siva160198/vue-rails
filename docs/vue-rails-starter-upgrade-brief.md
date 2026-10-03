# Brief pembaruan Vue Rails Starter dari pengalaman Travelplan

Tanggal: 1 Oktober 2026. Tujuan: dokumen ini dapat disalin ke repository `siva160198/vue-rails` sebagai tugas audit dan implementasi. Travelplan adalah aplikasi bisnis; starter harus tetap generik.

## Cara memakai brief ini

1. Di repository starter, bandingkan setiap butir dengan **kode, tes, konfigurasi, dan dokumentasi saat ini**. Status di bawah berasal dari README dan AGENTS.md publik, bukan audit menyeluruh atas seluruh source code. Tulis hasilnya: `sudah ada`, `sebagian`, `belum ada`, atau `tidak relevan`, disertai path bukti.
2. Implementasikan hanya gap yang reusable untuk proyek Rails/Vue lain. Jangan menyalin model, migration, permission, route, seed, atau desain bisnis Travelplan seperti Product, Availability, PCM, Debtor, dan Creditor.
3. Untuk setiap perubahan, perbarui tes terarah, kontrak OpenAPI jika API berubah, `.env.example` dan validasi boot jika ada variabel baru, dokumentasi operasi, serta `AGENTS.md`. Jangan menyalin `.env`, kredensial, data pengguna, atau kunci enkripsi.
4. Kerjakan dalam perubahan kecil yang bisa ditinjau. Pertahankan kompatibilitas sesi dan database melalui migrasi bertahap. Jangan mengklaim ISO/IEC 27001 compliant/certified hanya karena kode ini diterapkan.

## Fondasi starter yang sudah terdokumentasi; jangan dibuat ulang

README/AGENTS.md publik starter sudah menyebut Ruby 4.0.6, Rails 8.1 JSON API, Vue 3, Vite, Tailwind CSS 4, PostgreSQL, Rails native cookie session dan CSRF, email OTP, Pundit dan permission database, Rails/Vue i18n Indonesia-Inggris, toast global, `AsyncButton`, `useAuth`, `useServerTable`, keyset cursor, OpenAPI 3.1, Minitest/Vitest/Playwright, Docker, Solid Queue, readiness, backup/restore, serta CI keamanan. Dokumen itu juga menyebut TOTP, passkeys/WebAuthn, recovery code, step-up, audit log, dan enkripsi field profil dengan `SecurityEncryptor`. **Audit implementasi sebelum menyatakan salah satu belum ada.** Jangan menambah library baru hanya untuk mengganti mekanisme yang telah bekerja.

## Kandidat gap yang dapat dipindahkan

| Prioritas | Kandidat reusable | Bukti awal dan yang harus diaudit | Hasil yang diinginkan |
| --- | --- | --- | --- |
| P1 | **Session lock di halaman aktif** | README/AGENTS.md starter publik masih mendeskripsikan `401 AUTHENTICATION_REQUIRED` sebagai redirect ke Login. Audit `sessionExpirationCoordinator.js`, `api.js`, shell, dan flow unlock. | Saat sesi berakhir, halaman tetap terpasang dan form/modal yang belum disimpan tetap di memori di balik overlay blur dan inert. Unlock meminta password akun yang sama; OTP sesuai kebijakan. Tidak ada write yang otomatis diulang. Reset CSRF, batalkan request lama, buang respons stale, muat ulang permission; akses yang dicabut tetap terkunci. Reload/close tetap boleh kehilangan draft. |
| P1 | **Trusted device 30 hari dengan binding sesi** | Tidak tercantum dalam AGENTS.md publik; **belum diverifikasi di kode**. Audit model token, cookie, rotasi, revokasi, dan tes pencurian satu cookie. | Opt-in setelah OTP sukses; token acak disimpan aman, diputar saat dipakai, dibatasi device fingerprint kasar dan `authentication_version`. Sesi baru tetap butuh binding cookie HTTP-only yang berbeda. MFA wajib tidak boleh bypass. Perubahan password/email/MFA/akses mencabut trust. Jangan klaim aman bila seluruh profil browser dicuri; passkey memberi perlindungan lebih kuat. |
| P1 | **ISMS berbasis ISO/IEC 27001:2022 + Amd 1:2024** | Tidak tercantum dalam AGENTS.md publik; **belum diverifikasi pada dokumen lain**. | Tambahkan pedoman keamanan berbasis risiko untuk arsitektur, operasi, dan proses. Siapkan scope, inventaris aset, penilaian/treatment risiko, SoA, owner, status, bukti, residual risk, review berkala. Bedakan kontrol teknis yang terpasang dari proses organisasi yang belum berjalan. Jangan klaim sertifikasi tanpa sertifikat dan scope sah. |
| P2 | **Aturan komponen action UI yang seragam** | Starter sudah memakai TailAdmin dan `AsyncButton`, tetapi aturan `app-btn`/`TableActionButton` Travelplan tidak terlihat pada AGENTS.md publik. Audit `style.css`, komponen button, modal, serta responsif mobile/tablet. | Satu set varian primary/secondary/danger/icon/compact, action bar responsif, row action ikon pada mobile + teks pada layar lebih lebar. Semua operasi async memakai state loading kontekstual. Jangan menduplikasi varian TailAdmin bila sudah setara. |
| P2 | **Modal aman untuk form yang berubah** | Starter sudah punya `AppModal`; audit perilaku backdrop, Escape, modal bertumpuk, dan form dirty. | Klik backdrop tidak menghilangkan pekerjaan; penutupan form kotor meminta konfirmasi discard; Escape hanya menutup modal paling atas. Kondisi loading menahan penutupan. Tes interaksi mobile dan keyboard. |
| P2 | **Pencarian dalam dropdown yang efisien** | Audit `SelectInput.vue` dan picker yang ada. | Ketik langsung di dropdown, filter lokal untuk daftar master kecil; daftar besar memakai pencarian server dengan debounce, batas hasil, dan pembatalan request stale. Dapat dipakai keyboard, jelas empty/loading state, tidak menambah dependensi UI tanpa kebutuhan. |
| P2 | **UX OTP konsisten** | Starter sudah punya email OTP/TOTP/recovery; audit input login dan semua modal step-up/unlock. | Komponen satu kode dengan kotak per digit, paste/autofill, fokus, keyboard dan screen reader yang benar; satu state bersama. Jangan menyimpan OTP di browser storage. |
| P3 | **Panduan perlindungan field data pribadi** | Starter mendokumentasikan `SecurityEncryptor` untuk field profil; jangan menggantinya tanpa alasan. | Klasifikasikan field yang perlu enkripsi, pseudonimisasi, atau hash satu arah. Audit kunci, rotasi, akses API, pencarian, log, backup, dan migrasi plaintext. Pilih implementasi per kebutuhan; jangan menyatakan semua PII sudah terenkripsi. |

P1/P2/P3 menunjukkan urutan usulan, **bukan** hasil penilaian risiko formal. Jika kode starter sudah memiliki suatu kemampuan, cukup rapikan dokumentasi/tes yang tertinggal; jangan implementasikan ulang.

## Aturan penerapan untuk agent starter

- Pertahankan native Rails authentication, CSRF, Pundit, permission backend, `render_api_error` dengan kode stabil dan `details` object, OpenAPI, dan i18n dua bahasa.
- Akses pengguna yang tampak tersembunyi di frontend tetap harus ditolak oleh policy/controller. Tambahkan permission hanya untuk tindakan server yang baru.
- Untuk token dan cookie baru, definisikan masa berlaku, rotasi, revokasi, batas sesi, penyimpanan hash/token, log aman, dan skenario pengujian. Jangan masukkan rahasia ke repository.
- Untuk data baru yang tumbuh, gunakan pagination dan indeks yang sesuai. Batasi ukuran, durasi, dan laju request.
- Jangan menyalin `AGENTS.md` Travelplan seluruhnya. Ambil pedoman generik setelah memeriksa aturan starter yang sudah ada dan menyelesaikan konflik.
- Jalankan tes terarah sesuai perubahan, build frontend bila mengubah Vue, tes kontrak untuk API, dan cek keamanan yang relevan. Catat gap operasional yang tidak dapat diselesaikan oleh kode.

## Teks tugas siap tempel di starter

> Audit repository ini terhadap `docs/vue-rails-starter-upgrade-brief.md`. Untuk tiap kandidat, tunjukkan bukti file/tes dan beri status sudah ada, sebagian, belum ada, atau tidak relevan. Prioritaskan session lock, trusted-device binding, dan pedoman ISO/IEC 27001; lalu komponen UI reusable. Implementasikan gap yang sudah disetujui secara bertahap tanpa menyalin bisnis Travelplan atau merombak fitur starter yang telah ada. Perbarui API contract, permission, i18n, env example, dokumentasi, dan tes yang relevan. Laporkan perubahan, validasi, serta risiko yang masih terbuka; jangan klaim sertifikasi ISO.

## Referensi perbandingan

- Starter publik: https://github.com/siva160198/vue-rails
- README starter: https://github.com/siva160198/vue-rails/blob/main/README.md
- AGENTS.md starter: https://github.com/siva160198/vue-rails/blob/main/AGENTS.md
- Referensi standar: https://www.iso.org/standard/27001 dan https://webstore.iec.ch/en/publication/92579

Perbandingan ini adalah snapshot dokumentasi publik pada tanggal di atas. Branch starter dapat berubah; audit source code di branch tujuan tetap wajib sebelum mengerjakan gap.
