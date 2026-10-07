# Optional data-pipeline recipes / Fondasi pipeline opt-in

These executable services/jobs are available to derived projects; they deliberately
do not add business import menus, public upload routes, OAuth providers or product
tables. Only the existing dashboard report is wired into the core UI/API.

Fondasi ini bisa dipakai proyek turunan. Tidak ada menu import bisnis, endpoint upload
publik atau provider OAuth aktif secara default. Jangan menganggap adapter sudah aktif.

## Import

`ImportRun.submit!(owner:, adapter_key:, io:, submission_key:)` persists a bounded,
encrypted source then enqueues `ImportPipelineJob`. A stable 16–80 character submission
key must be unique per intentional submission; reusing it with different content fails.
At most three unfinished imports are allowed per owner. Duplicate submission does not
enqueue again. If enqueue fails after DB commit, the maintenance job repairs it.

Register an adapter in a Rails `config.to_prepare` initializer:

```ruby
DataPipelines::Registry.imports.register("customer_csv", -> { CustomerCsvAdapter.new })
```

The project-defined adapter supplies:

- `authorized?(owner)`: fresh Pundit/permission check, including ownership/tenant scope.
- `headers`: exact ordered, unique CSV column names (maximum 30).
- `sample_rows`: fabricated sample arrays, never production rows.
- `process!(row, owner:, idempotency_key:)`: bounded primary-database writes with a
  deterministic duplicate policy (reject/upsert/skip). No remote requests in import row
  transactions. Unexpected adapter failure ends the run; validation failure marks only
  the row as failed. Stable per-row keys are `import:<run id>:<row position>`.

UTF-8/BOM, comma or semicolon and quoted separators are supported. Limits: 1 MiB source,
2,000 rows, 30 columns, 4,000 bytes/cell, 50 rows per job. Parsing/staging happens in the
background, not the web request. Source is erased after staging and row payload after
processing; pending source/rows are encrypted. Run status/counters come from `progress`.
`sample_csv(owner:, adapter_key:)` and `failures_csv` produce safe CSV; failure exports
contain only row positions and stable codes, not original personal data.

CSV exports prefix spreadsheet formulas/control-leading values before CSV quoting.
Spreadsheet save/reopen behavior can undo mitigation: treat subsequent exports as new
untrusted input. See [OWASP CSV injection](https://community.owasp.org/attacks/CSV_Injection).

Untuk memasang halaman upload/progres: tambah permission, Pundit, route, rate limit,
CSRF, batas multipart di middleware/edge, OpenAPI, dua bahasa dan test akses ditolak.
Scope runs ke pemilik/tenant; jangan cari ID global. Poll minimal 5 detik, hentikan
saat tab tersembunyi, modal ditutup, atau status terminal; batalkan request lama.
Gunakan TailAdmin FileInput, AsyncButton, AppModal, toast dan DataTable dengan cursor.
No raw-source download endpoint is provided. Every sensitive export needs its own permission.

## Integrations / Integrasi

Register `DataPipelines::Registry.integrations.register("provider", -> { ProviderAdapter.new })`.
The adapter implements `authorized?(owner)` and
`fetch_page(credentials:, cursor:, limit:)`, returning:

```ruby
{ items: [{ id: "stable-provider-id", payload: { "metric" => 12 } }], next_cursor: nil }
```

Create an owner-scoped `IntegrationConnection` with the encrypted `credentials=` setter;
call `request_sync!`. Only one synchronization state per connection is active. Each job
fetches at most 100 items, upserts by unique external ID and commits items plus cursor
together. Maximum 10,000 items per run, 16 KiB/item, 4 KiB cursor. Do not make job args
contain credentials. `last_synced_at`, `status`, `failure_code`, `processed_items` are
safe status fields; ciphertext/credentials/cursor are never public status data.

Adapters use `DataPipelines::HttpClient` with a CODE-approved HTTPS origin/host list.
It rejects private/reserved/mapped destinations, pins the validated DNS address for
TLS, refuses redirects/environment proxies, sets connect/read/write timeouts, limits
response bytes and checks elapsed time while reading. It supports GET JSON; OAuth token
exchange and provider-specific consent/scopes must be reviewed/implemented in the derived
project, not by supplying arbitrary URLs or class names from the browser.

Raise `DataPipelines::Sync::TransientFailure` for quota/transient failures; Retry-After
is bounded to 1–3,600 seconds and at most three attempts. Delays enqueue later jobs,
never `sleep` a worker. Authentication expiration becomes `reconnect_required`.
Unknown/unauthorized providers fail closed. SQL writes and checkpoint advance atomically;
remote writes, if added by a project, require provider-side idempotency independently.

## Maintenance / Retensi

Separate bounded workers serve `imports`, `integrations`, and `maintenance`, preserving
the mail/default worker pool. Review deployment memory/DB connection capacity when
changing worker concurrency. Every five minutes the maintenance job checks at most 50
stale records of each type and permits at most three recovery enqueues before terminal
failure. Success resets the recovery counter. No unbounded recovery loop is permitted.
`PIPELINE_RETENTION_DAYS` (default 7) prunes terminal imports and expired integration
cache items in batches; choose retention deliberately for each derived product.

## Reporting / Laporan

`Reporting::DateRange` defines inclusive dates, UTC half-open SQL bounds and equal-length
previous periods. Invalid/future/reversed/>366-day ranges fail. `Reporting::DailyCount`
accepts an ALREADY-authorized relation and whitelisted timestamp column, performs two
grouped PostgreSQL queries, fills zero days and reconciles totals with the series.
`Reporting::Comparison` handles a zero baseline (`percentage: null` for new growth),
negative values and `lower_is_better` semantics. Never convert null to fake infinity.

The dashboard caches counts/report results for 30 seconds; user `created_at` is indexed.
Vue uses `reportContext`, `ReportDateFilter` and `ReportLineChart`; query state is shareable
in the URL and stale requests are aborted/discarded. Chart geometry preserves aspect
ratio, supports hover/focus/touch and shows loading, empty, error/retry states.
Use PostgreSQL aggregation for new metrics; do not download source tables into Vue.
Scope joins and aggregations carefully to avoid double-counting or cross-tenant leakage.
