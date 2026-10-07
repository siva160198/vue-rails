# Operations runbook

## Backup and restore

Set `DATABASE_URL`, store backups outside the application release, then run `bin/backup`.
The custom PostgreSQL dump is created with mode `0600`; files older than
`BACKUP_RETENTION_DAYS` are removed. Copy backups to encrypted off-site storage and test
a restore at least monthly in an isolated database:

```sh
DATABASE_URL=postgres://... RESTORE_CONFIRM=restore bin/restore /absolute/backup.dump
bin/rails db:migrate
bin/rails runner 'abort unless User.limit(1).exists?'
```

Never restore over production without an approved incident plan and a fresh backup.
CI executes this restore procedure against an isolated database on every change. Production
operators must still monitor off-site backup age and perform a provider-level recovery drill.

## Security operations

- Ship structured `security_audit` log events to append-only external storage and alert when
  its HMAC chain verification fails. Database retention is controlled by
  `AUDIT_LOG_RETENTION_DAYS`.
- Keep `PASSWORD_BREACH_CHECK_ENABLED` optional; its HIBP request contains only the first five
  SHA-1 characters and uses padded responses. Availability failures never reveal a password.
- Install ClamAV and set an absolute `CLAMSCAN_PATH` before enabling `MALWARE_SCAN_ENABLED`.
  Enabled scans fail closed and run with a bounded timeout.
- Review CSP reports without retaining query strings. Keep HSTS preload disabled until every
  current and future subdomain is permanently HTTPS.
- CI pins external actions by commit SHA and runs secret, static-code, dependency, container,
  SBOM, and OWASP ZAP checks. Dependabot updates must be reviewed rather than auto-merged.

## Deploy and rollback

Before the first release, ensure the PostgreSQL release role may enable `pg_trgm`, or
have a database administrator enable it. Indexed case-insensitive contains-search depends
on this extension.

1. Build one immutable image and run its test/security gates.
2. Take a database backup for destructive or irreversible migrations.
3. Run `bin/release` once, then switch traffic to web and worker processes from the same image.
4. Verify `/up`, authenticated `/api/v1/readiness` using the internal
   `X-Readiness-Token`, login, queue latency, email delivery, and error rate. Keep the
   readiness token out of browser code and rotate it like any other production secret.
5. Roll application traffic back to the previous image when code fails. Database rollback is
   explicit and reviewed; prefer forward-fix migrations after data has been transformed.

## Incident response

1. Record start time, affected release and request IDs; assign an incident owner.
2. Contain exposure by disabling the affected feature or rotating compromised credentials.
3. Preserve structured logs and audit logs; never paste secrets or personal data into tickets.
4. Restore service, verify database/queue/mail/storage checks, and notify affected users when required.
5. Write a blameless follow-up with timeline, impact, root cause, and preventive actions.

## Monitoring alerts

Alert on readiness failures, no worker heartbeat, failed jobs, queue latency above five minutes,
rate-limit saturation, retention backlog, orphaned upload growth, and PostgreSQL lock/statement
timeouts. Audit writes use deterministic shards; monitor contention per chain rather than assuming
a single global audit lock.
mail delivery failures, elevated HTTP 5xx responses, database pool saturation, disk usage, and
backup age. Sentry captures exceptions when configured; infrastructure metrics and uptime alerts
belong in the chosen hosting provider.

## Optional operational tooling / Tooling production opt-in

No cloud resources, alert destinations, IAM policies, retention locks or production
services are automatically created/activated by this repository. Set them up in a
private deployment and record evidence, rather than treating a sample config as proof.

Tidak ada layanan cloud atau alert production yang otomatis aktif. Pilih provider,
buat IAM/bucket/key secara privat, uji pengiriman dan restore, lalu catat buktinya.

### Backup off-site

`bin/backup` reserves the dump file with mode 0600 before writing. PostgreSQL passwords
are passed through the child environment, never in pg_dump/pg_restore argv. The dump
name includes a random suffix; a failed dump/upload never refreshes success evidence.

If `OFFSITE_BACKUP_BUCKET` and `OFFSITE_BACKUP_KMS_KEY_ID` are configured, the existing
AWS SDK streams/multipart-uploads to a random private key using SSE-KMS, then verifies
object length, encryption metadata and the uploaded source SHA-256 metadata. This
metadata check is NOT a restore or end-to-end checksum proof: periodically download
the object, verify the SHA-256 independently, and restore it into an isolated database.
Use the AWS default credential/role chain, not frontend/upload credentials. TLS, blocked
public access, bucket policy, KMS grants, versioning, lifecycle and Object Lock retention
are provider/operator responsibilities. Review retention locks before enabling them;
they can make deletion intentionally impossible until expiry. Keep PostgreSQL dumps,
private avatars/storage, queue state and backup encryption keys in the recovery scope.

`BACKUP_STATUS_FILE` writes an atomic private JSON success record outside the release.
Its directory must already exist. Mount that private operations volume in the maintenance
worker if monitoring backup age. Schedule `bin/backup` outside the web process using a
private service/timer and alert on command failure; keep local pruning only after a
successful optional upload. Local-only backup does not count as off-site verification.

See [AWS Ruby S3 upload API](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html)
for provider behavior. This starter does not assume an S3-compatible provider supports KMS.

### Audit sink and alert delivery

`docs/operations/vector.example.toml` is an OPTIONAL external collector example, not a
running service. Export the Rails structured stdout JSON lines into its read-only file
source (adjust the source to your approved runtime log driver), mount a private durable
buffer, pin/review a Vector version, validate the config and test it in staging.

The remap allowlists minimal audit/operational event fields and drops other request
logs. The archive sink uses a separate private SSE-KMS audit bucket; require default
Object Lock retention, least privilege and an IAM role without delete/retention-bypass
rights. An approved HTTPS receiver receives only stable operational codes. Secrets
`AUDIT_LOG_*`/`OPERATIONS_ALERT_*` belong to the collector, never the Vue bundle.
Test archive restart/replay behavior and duplicated events; consumers deduplicate audit
records by `audit_id`/digest. Monitor buffer size, dropped events, delivery retries,
collector heartbeat and on-call acknowledgment independently of the application.

Validate against [Vector's S3 sink reference](https://vector.dev/docs/reference/configuration/sinks/aws_s3/).
Bucket encryption alone is NOT immutability. Configure retention/IAM and retain evidence.

### Scheduled health and audit checks

`OPERATIONS_MONITOR_ENABLED=true` enables a five-minute maintenance check of database,
worker heartbeat, queue latency, failed jobs and backup age. Enabling it requires an
absolute `BACKUP_STATUS_FILE`. Failed checks emit minimal `operational_alert` JSON events,
deduplicated per code for 15 minutes in shared Rails cache. Configure infrastructure
uptime/CPU/memory/disk/DB pool metrics separately; a stopped scheduler cannot report its
own outage. SMTP delivery and provider latency need independent delivery probes.

`AUDIT_INTEGRITY_CHECK_ENABLED=true` enables the nightly HMAC-chain check. Verification
streams 500 records per batch across chain shards instead of loading the full audit
table. Schedule it with adequate capacity and export the earliest/latest chain anchors
privately: retained local chains alone cannot prove a deleted prefix or recover a lost
root key. An external archive and independent reconciliation are still required.

### Evidence gate and recovery drill

Copy `docs/operations/deployment-evidence.example.yml` OUTSIDE the public repository,
chmod 0600, fill named owners, approvals, RPO/RTO, current test dates and private evidence.
Run `bin/production_check /private/deployment-evidence.yml` before promotion. It checks
completeness/freshness (31 days), risk acceptance and review date; it does not inspect
provider permissions, certify ISO compliance or authenticate the evidence itself.

At least monthly, download a real off-site object to a private isolated environment,
verify SHA-256, restore DB and private storage, restore appropriate historical keys,
run migrations/health/login/mail/queue checks and measure RPO/RTO. Do not reuse production
email destinations in a recovery drill. Record timestamps, responsible reviewer,
measured recovery results, failures and follow-up privately. Keep the template ISMS
register pending until real evidence is reviewed. Never run restore over production
as an automatic test or fallback.
