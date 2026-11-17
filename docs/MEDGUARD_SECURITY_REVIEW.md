# Security review — 18 November 2026

Current candidate-tree Gitleaks scan: completed, 10 findings. Five Firebase client-key occurrences require Google Cloud API-restriction review; five are deliberate dummy key/JWT fixtures in tests. No actual `.env`, private signing key, backup key, medical archive or uploaded medical file was included in the scanned Git candidate tree.

Full Git-history scan: completed, 12 findings. In addition to the above categories, an older AI configuration added an encoded Gemini credential. It is absent from current source. Rotate that historical credential manually; source removal or obfuscation does not revoke it. The historical commit is already an ancestor of remote main. No history rewrite or force push was performed.

Production dependency audit reported zero known advisories at the recorded run. This is an advisory check, not a security guarantee.

Changes reviewed include bearer/session verification, token hashing with legacy compatibility, owner/recipient grant checks, expiry/revoke handling, stored-draft/account-switch isolation, legacy file real paths/symlinks, private response caching, error/log redaction, upload limits and fail-closed scanning, scan signature freshness, bounded JSON/AI histories, explicit chat consent, protected custom test keys, deletion-worker ownership and signing-file exclusions.

Remaining security/operational gates: rotate the exposed historical Gemini key; inspect Firebase restrictions; deploy/test actual private ClamAV and fresh signatures; verify durable database/GridFS backups and restoration; enforce an actual retention policy; verify the physical-phone/account-switch flows; review provider/privacy/legal/monitoring requirements. Current automatic/local tests do not establish regulatory compliance or a complete penetration test.

Detailed redacted machine reports are available separately. They intentionally omit secret values. Do not post unredacted scanner output or credential-bearing logs.
