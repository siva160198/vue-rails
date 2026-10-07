# ISMS starter / Panduan manajemen keamanan informasi

Status: draft template, 2026-10-07. Owner/approver: unassigned.

## Purpose / Tujuan

This is a risk-based starting point for a project derived from Vue Rails, not a
claim of ISO compliance or certification. Repository controls do not demonstrate
that an organization operates an ISMS. Adapt and approve this document before
production. Obtain the authorized standard and qualified advice for a full assessment.

Ini adalah pedoman awal berbasis risiko, bukan klaim patuh/bersertifikat ISO.
Kontrol dalam kode tidak membuktikan proses organisasi sudah berjalan. Sesuaikan,
tetapkan penanggung jawab, dan setujui dokumen ini sebelum production.

References / Referensi resmi:

- [ISO/IEC 27001:2022](https://www.iso.org/standard/27001?archive=all): ISMS and risk-management framework.
- [Amendment 1:2024](https://www.iso.org/standard/88435.html): climate action changes. Record whether climate-related conditions affect organizational context, supplier continuity, and interested-party needs; do not assume non-applicability.

## Scope and context / Lingkup dan konteks

Proposed scope: source, build/release pipeline, Rails API, Vue SPA, PostgreSQL,
Solid Queue, email service, private avatar storage, backups, deployment network,
administrator endpoints, and personnel/suppliers operating them. Exclusions require
written rationale and approval. A starter cannot define a customer's final scope.

Lingkup usulan mencakup kode, CI/CD, Rails/Vue, database/queue, email, penyimpanan
foto, backup, jaringan deployment, serta personel/pemasok. Pengecualian harus
beralasan dan disetujui, bukan diasumsikan dari starter.

Before deployment record / Sebelum deployment catat:

- Organization, service boundary, data locations, applicable contractual/regulatory obligations, interested parties and their requirements.
- Data classification: public source; internal operational metadata; confidential profile/contact/device data; restricted credentials, MFA material, keys, and backups.
- Asset owners, supplier/subprocessor dependencies, retention/deletion periods, acceptable use and incident contacts.
- Climate/context relevance assessment, rationale, owner and review date.
- Approved availability objectives, RTO/RPO, recovery dependencies, objectives/metrics and budget.

Use `register.yml` as a private deployment-specific working register. Do not commit
real customer data, network details, evidence links with tokens, or secret inventories
to this public template. Evidence must be access-controlled and time-stamped.

Gunakan `register.yml` sebagai template untuk register privat deployment. Jangan
commit data pelanggan, detail jaringan, token, atau rahasia ke template publik.

## Roles / Tanggung jawab

Management approves scope, policy, budget and residual risk. Security owner maintains
risk/SoA/incident records. Engineering owner operates secure changes and testing.
Operations owner manages keys, deployments, supplier access and recovery. Privacy
owner reviews collection, retention and obligations. Independent reviewer performs
internal audits; do not let the control author be the sole reviewer. One person may
hold multiple roles only when conflicts and compensating review are documented.

Manajemen menyetujui lingkup/kebijakan/risiko residual; pemilik keamanan mengelola
risiko, SoA, dan insiden; engineering/operations menjaga perubahan, akses, kunci dan
pemulihan; penanggung jawab privasi meninjau data; reviewer independen mengaudit.
Seluruh jabatan masih harus ditetapkan oleh organisasi.

## Risk method / Metode risiko

Use likelihood 1–5 and impact 1–5; score = likelihood × impact. Impact includes
confidentiality, integrity, availability and people/business consequences. Example
thresholds: 1–4 low, 5–9 medium, 10–16 high, 17–25 critical. These are proposed,
not measured scores or universally mandated thresholds. Management must approve
acceptance criteria. High/critical risk needs treatment before release or explicit,
time-bound management acceptance; controls cannot self-approve acceptance.

Nilai kemungkinan/dampak 1–5, skor hasil perkalian. Ambang di atas hanya usulan.
Setiap risiko mencatat ancaman, kelemahan, aset, kontrol awal, skor sebelum/sesudah,
owner, tenggat, bukti efektivitas, dan persetujuan risiko residual. Pilih mitigasi,
penghindaran, transfer, atau penerimaan dengan alasan dan batas waktu.

## Statement of Applicability / SoA

`register.yml` contains a starter control inventory, NOT a complete Annex A SoA.
Using an authorized copy, assess every Annex A control and any extra controls required
by risk/obligations. Record applicability, inclusion/exclusion rationale, owner,
implementation status, evidence, and review. Do not reproduce the copyrighted standard
in this repository. A code reference is implementation evidence only, not proof of
ongoing effectiveness. Pending operational controls must stay pending until verified.

Register ini bukan SoA Annex A lengkap. Nilai semua kontrol dari standar resmi,
catat alasan berlaku/tidak berlaku, owner, status, bukti, dan tinjauan. Path kode
bukan bukti bahwa proses operasional berjalan atau kontrol selalu efektif.

## Operating cycle / Siklus operasi

- Every release: review API/permission/security changes, test gates, dependency/SBOM results, migration/recovery plan and approvals. Record exceptions, never silently waive gates.
- Monthly: inspect security alerts, job/mail failures, patch backlog, access changes, backup completion and expiring exceptions.
- Quarterly: review access and trusted devices, risks, supplier access, retention, key inventory, restore drill against an isolated database, and metrics.
- Annually and after material change/incident: review scope/context, perform independent internal audit and incident exercise, management review, approve updated risk treatment/SoA.
- Follow `docs/operations.md` for actual restore/release procedures; define RTO/RPO and record measured recovery results privately.

Setiap rilis tinjau keamanan dan rollback; bulanan tinjau alert/patch/backup;
triwulanan tinjau akses/risiko/pemasok dan uji restore; tahunan atau setelah insiden
lakukan audit independen, latihan insiden, dan management review. Jadwal ini usulan
yang harus disahkan organisasi, belum bukti pelaksanaan.

## Incident and corrective action / Insiden dan perbaikan

Record detection time, severity, affected scope and incident owner. Preserve minimal
evidence without copying tokens/passwords into tickets. Contain by revoking sessions
and trusted devices, disabling compromised accounts, rotating affected credentials,
or isolating a release. Follow an approved recovery plan; do not overwrite production
without backup and approval. Determine notification obligations with the responsible
owner. Document root cause, action/deadline, effectiveness retest and closure approval.

Catat waktu/tingkat/lingkup/owner, amankan bukti tanpa rahasia, cabut sesi/trust dan
rotasi kredensial sesuai lingkup, lakukan pemulihan yang disetujui. Owner menentukan
kewajiban pemberitahuan; tindak lanjut mencakup akar masalah, tenggat, uji ulang dan
persetujuan penutupan.

## Metrics and evidence / Metrik dan bukti

Track unresolved high risks, patch lead time, access-review completion, MFA exceptions,
restore success and measured RTO/RPO, alert response time, incidents and overdue actions.
Set targets/owners before collecting. Retain release approvals, sanitized test/scan
reports, access-review decisions, restore exercises, supplier assessments, training,
internal audit and management-review records under a private evidence retention policy.

Pantau risiko tinggi, patch, review akses/MFA, hasil restore, respons alert dan
tindak lanjut. Tetapkan target, owner, serta retensi bukti secara privat.

## Open organizational gaps / Gap organisasi

Scope approval, legal/privacy assessment, real asset/supplier register, risk scoring,
complete SoA, named owners, staff training, physical controls, independent audit,
management review and evidence are NOT supplied by this repository. Production
readiness requires these decisions and validation of deployed controls.

Persetujuan lingkup, penilaian legal/privasi, register nyata, skor risiko, SoA lengkap,
owner, pelatihan, kontrol fisik, audit independen, dan management review belum
dilaksanakan hanya dengan menambahkan dokumen ini.
