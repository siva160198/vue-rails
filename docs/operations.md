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

1. Build one immutable image and run its test/security gates.
2. Take a database backup for destructive or irreversible migrations.
3. Run `bin/release` once, then switch traffic to web and worker processes from the same image.
4. Verify `/up`, `/api/v1/readiness`, login, queue latency, email delivery, and error rate.
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
mail delivery failures, elevated HTTP 5xx responses, database pool saturation, disk usage, and
backup age. Sentry captures exceptions when configured; infrastructure metrics and uptime alerts
belong in the chosen hosting provider.
