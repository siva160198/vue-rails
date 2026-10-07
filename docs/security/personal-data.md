# Personal data / Data pribadi

This is an engineering classification baseline, not a legal opinion or a claim that
all PII is encrypted. Deployment owners must approve purpose, access, retention,
deletion obligations, suppliers and risk in a private copy of the ISMS register.

Ini pakem klasifikasi teknis, bukan pendapat hukum atau klaim semua PII terenkripsi.
Owner deployment menyetujui tujuan, akses, retensi, penghapusan dan supplier.

| Data | Treatment / Perlakuan | Reason / Alasan |
| --- | --- | --- |
| Password | Native bcrypt digest; never reversible | Authenticate, never disclose / autentikasi, bukan ditampilkan |
| OTP, recovery, trust tokens | Short-lived/high-entropy digests, bounded attempts | Verify without retaining plaintext / verifikasi tanpa kode asli |
| Phone | `SecurityEncryptor` authenticated encryption | Display only to authorized owner / tampilkan ke pemilik berizin |
| TOTP and integration secrets | Encrypted; never serialize secrets | Server must use the secret / server membutuhkan nilai asli |
| Import source and row payload | Encrypted while pending; source cleared after staging, payload cleared after processing | Minimize temporary PII / minimalkan data sementara |
| Integration cached items/cursor | Encrypted with purpose-separated keys; bounded page/item size and configurable retention | Scoped synchronized cache / cache sinkronisasi terkontrol |
| Email and first/last name | Currently plaintext, permission-scoped | Identity/search; names/email are NOT encrypted by this starter |
| Attempted account identifier | Server-keyed HMAC, not plain SHA-256 | Reduce offline guessing / kurangi tebakan offline |
| Session/audit IP and user-agent | Currently plaintext, restricted API and bounded retention | Investigations; treat as personal data / investigasi, tetap PII |
| Profile photo | Private storage, AVIF metadata stripping, authorized proxy | File is not application-encrypted; storage encryption is required |
| Backups | Private local file, optional off-site SSE-KMS, separate IAM role | Encryption does not replace access controls or restore testing |

## Rules / Aturan

- Do not encrypt fields indiscriminately. Document which fields require reversible
  display, exact lookup, aggregation or irreversible verification. A digest is not
  encryption; pseudonymization is not anonymization. Searchable email/name fields
  require database/storage encryption and least-privilege database access.
- API responses use explicit allowlists. Never render `ImportRun`, `ImportRow`,
  `IntegrationConnection` or `IntegrationItem` directly: default Active Record JSON
  includes ciphertext columns. Expose only authorized `progress`/status summaries;
  page cached items through the server pagination concern after ownership/policy checks.
- Do not send rows, secrets, plaintext email, phone, OTP, request bodies or credential
  objects to logs, tracing, error reporting, queue arguments, browser storage or fixtures.
  Pipeline jobs receive database IDs only. Failures retain stable codes, not exception text.
- Key inventory must name owner, purpose, provider, version, recovery path and rotation
  approvals in PRIVATE storage. `SecurityEncryptor` currently derives keys from the Rails
  root key; rotating that root without a migration can make encrypted fields unreadable.
  There is no automatic historical-key migration in this starter.
- Plan rotation with a tested dual-read/new-write period, an old/new key inventory and
  bounded idempotent re-encryption batches in an isolated copy. Verify ciphertext
  expansion, null handling, field-purpose binding and rollback before switching keys.
  Retain old backup keys for the approved backup lifetime; never overwrite them early.
- Legacy phone plaintext reads support existing migrations, not permission to add new
  plaintext sensitive fields. For new fields, use the encrypted setter and test raw DB
  values, serializer allowlists, validation and tampering. JSON-encode arbitrary source
  text before encryption so an attacker-controlled `enc:v1:` prefix is not interpreted
  as an already-encrypted value.
- Deletion/retention must cover primary DB, queue/cache, upload storage, import rows,
  provider caches, audit logs and backups. Do not silently erase compliance evidence or
  claim immediate deletion from immutable backups; document retention and legal holds.
- Supplier access, local developer exports and analytics require separate approval.
  Never commit a real sample CSV, key inventory, customer data or private evidence.

Setiap field baru wajib punya tujuan, klasifikasi, owner, izin, retensi, serializer
allowlist, aturan log, dan test. Rotasi kunci serta restore harus diuji sebelum production.
