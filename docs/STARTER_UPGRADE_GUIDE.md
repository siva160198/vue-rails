# Vue Rails Starter Upgrade Pack

Dokumen ini adalah panduan portabel untuk memperbarui repository
`siva160198/vue-rails` berdasarkan pola yang sudah digunakan dan diuji di
Pulseboard. Salin dokumen ini bersama `docs/starter_upgrade_manifest.yml` ke
starter, lalu minta agent menjalankan fase audit sebelum mengubah kode.

## Baseline yang dibandingkan

- Basis awal Pulseboard: `56f584eb76445f62919fe0b98d547fc2cddc995b`
- `origin/main` saat audit 1 Oktober 2026: `0729c18`
- Stack Pulseboard: Rails 8.1 JSON API, Ruby 4, PostgreSQL, Vue 3, Vite 8,
  Tailwind CSS 4, Solid Queue, Pundit, Minitest, Vitest, dan Playwright.

Starter upstream sudah memiliki keamanan akun, session authentication,
permissions, OTP controls, passkeys, audit log, bilingual UI, server table,
OpenAPI, observability, dan CI. Jangan menyalin ulang fitur tersebut sebelum
memeriksa implementasi terbaru di starter.

## Cara menggunakan pack ini

1. Update branch starter dan buat branch upgrade baru.
2. Salin kedua file upgrade ini ke `docs/` pada starter.
3. Jalankan audit berdasarkan `starter_upgrade_manifest.yml`.
4. Untuk setiap capability, tandai `present`, `partial`, `missing`, atau
   `not_applicable`, disertai bukti file dan test.
5. Terapkan hanya capability `partial` atau `missing`, satu fase per perubahan.
6. Jangan menyalin model, migration, menu, permission, atau istilah bisnis
   Pulseboard kecuali starter memang memerlukan contoh modularnya.

## Capability generik yang layak dibawa ke starter

### P0 — fondasi yang disarankan

#### 1. Konfigurasi aplikasi terpusat melalui environment

Semua nilai yang berbeda antar-installation harus berasal dari environment:

- `APP_NAME`, `APP_HOST`, `APP_PORT`, `APP_PROTOCOL`
- `FRONTEND_URL` dan optional `FRONTEND_ORIGIN`
- `RAILS_BINDING`, `RAILS_PORT`, `VITE_HOST`, `VITE_PORT`, `VITE_RAILS_URL`
- nama database development/test/queue
- mailer identity dan SMTP
- security limits, retention, queue health, storage, dan monitoring

Gunakan `.env.example` sebagai kontrak tanpa secret. `.env` hanya untuk
development dan harus di-ignore. `dotenv-rails` boleh dipakai hanya pada grup
development/test. Production harus menerima environment dari platform deploy.

Nama aplikasi tidak boleh tersebar sebagai string hardcoded. Rails, email,
manifest, HTML title, WebAuthn RP name, dan Vue harus membaca sumber konfigurasi
yang sama dengan fallback aman.

#### 2. Development runner yang konsisten

`bin/dev` dan `Procfile.dev` harus memakai port/binding dari environment dan
menjalankan:

```text
Rails: 0.0.0.0:${RAILS_PORT}
Vite:  0.0.0.0:${VITE_PORT}
```

Vite mem-proxy `/api` dan `/rails/active_storage` ke `VITE_RAILS_URL`. Binding
`0.0.0.0` memungkinkan pengujian lewat device lain di LAN, tetapi URL publik,
CORS, cookie, dan trusted hosts tetap harus dibatasi sesuai environment.

Catatan audit: pada snapshot Pulseboard, `Procfile.dev` sudah environment-aware,
tetapi `bin/dev` masih hardcode Rails `3000`. Starter sebaiknya menjadikan satu
sumber konfigurasi agar kedua cara menjalankan app tidak berbeda.

#### 3. App config untuk Vue

Sediakan service kecil untuk membaca konfigurasi publik seperti nama aplikasi,
environment, release, timeout API, dan feature availability. Jangan pernah
mengekspor secret Rails ke bundle Vue.

`vite.config.js` boleh meng-inject hanya nilai publik. Semua nilai sensitif tetap
berada di backend.

#### 4. Kontrak API dan state async yang konsisten

- Semua API baru tetap di `/api/v1`.
- Gunakan error envelope starter dan request ID yang sudah ada.
- Semua mutation harus mempunyai loading state, disable duplicate submission,
  toast hasil, dan error state yang dapat ditindaklanjuti.
- Halaman data harus mempunyai loading, empty, error, retry, dan stale states.
- Jangan menjadikan authorization Vue sebagai security boundary.
- Setiap endpoint protected wajib memakai Pundit.

#### 5. Quality gates lengkap

`bin/ci` harus mencakup minimum:

- RuboCop
- bundler-audit
- importmap audit jika importmap tetap digunakan
- Brakeman dengan failure on warning/error
- Rails tests
- seed replant test
- Vitest frontend tests
- Vite production build
- Playwright smoke test pada CI yang mendukung browser
- validasi OpenAPI

Node harus memenuhi engine Vite (`>=20.19.0` atau versi LTS lebih baru yang
kompatibel). Jangan menerima build yang hanya kebetulan berhasil pada Node lama.

### P1 — pola reusable untuk aplikasi bisnis

#### 6. Server-backed table contract

Standarkan table besar dengan parameter:

```text
page atau cursor
per_page
s
sort
direction
filter domain
```

Backend harus mengizinkan hanya kolom sort/filter yang di-whitelist. Response
harus mengandung rows dan metadata pagination. Gunakan debounce untuk pencarian
dan batalkan/abaikan response lama saat filter berubah.

Tabel harus mendukung keyboard, loading overlay yang tidak menghapus layout,
empty state, error state, sortable header, dan horizontal scroll hanya bila
kolom kritis memang tidak dapat diringkas.

#### 7. Global report/date context

Untuk aplikasi reporting, gunakan context/composable bersama yang menyimpan:

- scope/tenant/resource aktif
- start date dan end date
- comparison mode
- comparison start/end
- filter yang memang lintas halaman

State penting harus tercermin di query string agar URL dapat dibookmark dan
dibagikan. Kalkulasi range dan comparison wajib terpusat di backend; Vue hanya
menampilkan hasil.

Response report yang dianjurkan:

```json
{
  "current": {},
  "comparison": {},
  "changes": {},
  "meta": { "generated_at": "...", "filters": {} }
}
```

Tangani previous value nol tanpa `Infinity`/`NaN`. Untuk metrik yang penurunan
angkanya justru baik, arah warna harus ditentukan oleh metadata/semantik metrik,
bukan sekadar tanda positif atau negatif.

#### 8. Reusable chart contract

Line chart generik harus memiliki:

- current dan comparison series
- label/legend yang jelas
- tooltip berisi periode, nama metrik, dan nilai terformat
- metric toggles bila lebih dari satu series
- responsive aspect ratio tanpa menarik/distorsi SVG
- loading, empty, dan error state
- formatter angka, persen, mata uang, dan tanggal

Gunakan `viewBox` proporsional. Jangan memakai
`preserveAspectRatio="none"` untuk SVG yang berisi titik/circle karena titik akan
terlihat gepeng atau tertarik.

#### 9. Background import pipeline

CSV/Excel import yang besar tidak boleh diproses di request web. Pola generik:

```text
Upload -> validate envelope -> persist import run -> enqueue job
       -> parse/normalize -> validate rows -> transaction/upsert
       -> persist row outcomes -> summary and downloadable errors
```

Import run minimal menyimpan status, filename, checksum, counts, timestamps,
requesting user, dan sanitized failure reason. Row outcome membedakan:

- created
- updated
- identical duplicate
- failed
- skipped (jika memang ada aturan eksplisit)

Duplicate policy harus eksplisit, deterministic, dan berbasis business key.
Preview/dry-run dianjurkan untuk import berisiko. Parser delimiter harus dapat
mendeteksi koma atau titik koma. File type, ukuran, encoding, formula injection,
dan jumlah row wajib dibatasi.

`csv` adalah dependency backend yang masuk akal. `jszip` hanya diperlukan jika
fitur benar-benar membuat/membaca archive atau format Office; jangan tambahkan
dependency tanpa use case.

#### 10. Query/report service layer

Agregasi report tidak diletakkan di controller atau dihitung dari seluruh row
di Vue. Gunakan query/service object Rails untuk:

- normalisasi filter
- current/previous period
- aggregation database
- safe division dan change calculation
- serialization contract

Hindari N+1, whitelist sorting, gunakan index untuk filter utama, dan tambahkan
request/service tests yang membuktikan bahwa total summary sama dengan detail.

#### 11. External integration pattern

Untuk OAuth/API pihak ketiga gunakan pola generik:

```text
Connection -> encrypted credential/token -> property/source binding
           -> sync run -> bounded background jobs -> local normalized data
```

Aturan:

- scope minimum/read-only
- encrypt token at rest
- jangan log secret, auth code, access token, refresh token, cookie, atau OTP
- page request membaca database lokal, bukan menunggu provider
- job idempotent, retry-safe, chunked, quota-aware, dan observable
- authorization failure menjadi `requires_reconnection` tanpa menghapus history
- simpan sync status dan `last_successful_sync_at`

Provider-specific SDK tidak termasuk dependency inti starter. Tambahkan Google,
WordPress, S3, atau provider lain hanya melalui module/recipe opsional.

### P2 — recipe opsional, jangan aktif secara default

#### 12. Analytics/reporting recipe

Yang dapat diekspor sebagai contoh arsitektur, bukan fitur default:

- `Analytics::DateRange`
- `Analytics::ComparisonCalculator`
- `Analytics::UrlNormalizer`
- background sync planner
- daily metric tables dengan composite unique index
- chart + KPI comparison contract

Hindari membawa Google SDK dan schema analytics ke starter inti.

#### 13. Content/WordPress recipe

Yang reusable:

- source configuration per website/tenant
- paginated synchronization
- locale-aware endpoint handling
- locally cached post metadata
- background sync and stale state

Content calendar, SEO evidence, dan performance review adalah module produk,
bukan baseline starter.

#### 14. Bulk export recipe

Export harus memakai filter dan formula yang sama dengan report layar. Untuk
dataset besar, jalankan background job dan berikan hasil downloadable dengan
masa berlaku. Lindungi spreadsheet dari formula injection pada value yang
diawali `=`, `+`, `-`, atau `@` jika diekspor sebagai CSV.

## Aturan arsitektur untuk AGENTS.md starter

Blok berikut siap disalin ke bagian instruction starter:

```md
## Modular application rules

- Audit the current implementation before adding a dependency or capability.
- Classify requested work as core starter infrastructure, optional recipe, or
  product-domain code. Keep domain modules out of the starter core.
- Rails remains a JSON API under `/api/v1`; Vue remains a separate Vite SPA.
- Preserve Rails session authentication, Pundit authorization, the shared API
  client, global toast, localization, request IDs, and the API error contract.
- Every protected server action must be authorized server-side.
- Put third-party API logic in services and long-running work in bounded,
  idempotent Active Jobs backed by Solid Queue.
- Dashboard and report requests should read locally stored data, not block on
  third-party API calls.
- Put report calculations and comparison semantics in Rails services/query
  objects, never independently in several Vue pages.
- Server-backed tables must whitelist sort/filter fields and expose loading,
  empty, error, retry, and pagination states.
- All user-facing text ships in English and Indonesian.
- Every API change updates `docs/openapi.yml` and includes request tests.
- Every environment variable is documented in `.env.example`; real secrets are
  never committed or exposed to Vue.
- New migrations must be reversible/safe, indexed for expected access paths,
  and compatible with existing production data.
- Do not copy Pulseboard-specific booking, platform, SEO, website, or content
  schemas into the starter unless explicitly implementing that optional recipe.
- Do not refactor unrelated modules while adopting a capability.
- Verify with targeted tests first, then the complete relevant CI suite.
```

## Urutan adopsi yang aman

1. Sinkronkan starter dengan upstream terbaru dan jalankan baseline CI.
2. Audit app configuration, `bin/dev`, Procfile, Docker, and deployment config.
3. Tambahkan frontend config contract dan environment documentation.
4. Lengkapi frontend CI/build/E2E gates.
5. Standardkan table, async states, dan report comparison utilities.
6. Tambahkan generic import framework bila starter memang perlu bulk import.
7. Dokumentasikan recipes integrations/reporting sebagai contoh terpisah.
8. Baru tambahkan provider atau domain module pada aplikasi turunan.

## Definition of done per capability

- Audit status dan evidence tercatat.
- Tidak menduplikasi capability upstream.
- Backend contract dan permission jelas.
- English dan Indonesian tersedia.
- OpenAPI diperbarui jika API berubah.
- Unit/request/component tests ditambahkan.
- Loading, empty, error, retry, and unauthorized states diuji.
- Production build dan security checks lolos.
- `.env.example` dan operations documentation diperbarui.
- Tidak ada credential atau data nyata di commit.

## Yang tidak boleh diekspor ke starter inti

- credential Google/SMTP/S3 atau isi `.env`
- nama, domain, database, seed account, dan branding Pulseboard
- data booking/platform dan sample produksi
- schema GA4/GSC, booking, platform, SEO, atau content plan sebagai default
- menu produk yang belum mempunyai implementation
- hardcoded property IDs, website IDs, status bisnis, currency, atau timezone

Gunakan module/recipe opsional untuk semua hal tersebut.

