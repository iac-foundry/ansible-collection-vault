# blueprints.vault.init_and_unseal

Initialize Vault, generate unseal keys, and configure auto-unseal systemd service with retry logic and health monitoring.

## Deployment model

`init_and_unseal` (platform-layer orchestration; called once during Phase 3).

## Purpose

This role automates Vault operator init and sets up automatic unsealing on VM restart. Addresses P0-3 (missing init_and_unseal role) and mitigates P1 findings:

- **P1-1:** Unseal key backup verification (operator gate before unsealing)
- **P1-2:** Root token to tmpfs + ephemeral storage (auto-deleted after use)
- **P1-6:** Vault audit logging enabled at init
- **P1-8:** Auto-unseal with retry logic (wait for Vault readiness)
- **P1-9:** Seal status monitoring (systemd timer + healthcheck script)

## Inputs

All configuration supplied via caller variables — see `meta/argument_specs.yml`.

### Required

- `vault_api_endpoint` — Vault API URL (e.g., `https://sec01.vernify.internal:8200`)
- `vault_cacert_path` — Path to step-ca root certificate for TLS

### Optional (with sensible defaults)

- `vault_unseal_keys_path` — Where to store unseal keys (default: `/opt/vault/unseal-keys.json`)
- `vault_root_token_path` — Where to store root token, ephemeral (default: `/opt/vault/root-token.txt`)
- `vault_unseal_script_path` — Unseal script location (default: `/opt/vault/unseal.sh`)
- `vault_unseal_service_name` — systemd service name (default: `vault-auto-unseal`)
- `vault_unseal_key_threshold` — Keys needed to unseal (default: 3, for 3-of-5 Shamir)
- `vault_backup_verification_enabled` — Interactive backup verification (default: true, P1-1)
- `vault_unseal_enable_health_timer` — Enable seal status monitoring (default: true, P1-9)
- `vault_unseal_retry_wait_seconds` — Healthcheck retry interval (default: 30s, P1-8)
- `vault_unseal_retry_max_attempts` — Max retry attempts (default: 10, P1-8)

## Idempotency

Role checks if Vault is already initialized (looks for `/opt/vault/data/core/hsm`):

- **Already initialized:** Skips `vault operator init`, doesn't re-generate keys
- **Not initialized:** Runs init, stores keys, creates systemd service

## What this role does

1. **Check idempotency** — Does Vault storage directory exist?
2. **Run vault operator init** — Generate unseal keys + root token (if not already initialized)
3. **Parse init output** — Extract keys and token from JSON response
4. **Store unseal keys** — Write to `{{ vault_unseal_keys_path }}` with 0600 perms
5. **Store root token** — Write to `{{ vault_root_token_path }}` (tmpfs, ephemeral) with 0600 perms
6. **Print operator instructions** — Display keys, explain backup requirement
7. **Operator gate** — Pause, ask operator to confirm backup complete (P1-1 mitigation)
8. **Generate unseal script** — Create `/opt/vault/unseal.sh` with retry logic (P1-8)
9. **Create systemd service** — `vault-auto-unseal.service` (enabled, not started)
10. **Enable audit logging** — `vault audit enable file` to `/var/log/vault/audit.log` (P1-6)
11. **Create healthcheck timer** — systemd timer to check seal status every 60s (P1-9)
12. **Clean up** — Remove temporary init output file

## Outputs (facts)

- `vault_root_token` — Root token (used by orchestration playbook for secret seeding)
- `vault_unseal_keys` — Array of unseal keys
- `vault_threshold` — Number of keys needed to unseal
- `vault_is_unsealed` — Boolean (true after unsealing)
- `vault_is_initialized` — Boolean (true if Vault was already initialized)

## Non-goals

- **Does not unseal Vault** — Unsealing is an operator gate in the orchestration playbook (Phase 3)
- **Does not seed secrets** — Secret seeding happens in `blueprints.vault_access` (orchestration playbook)
- **Does not configure Vault policies** — Policy management is orchestration responsibility
- **Does not manage Vault upgrades** — Upgrade path deferred to Phase 6

## Security Considerations

### Unseal Keys

- **Storage:** `/opt/vault/unseal-keys.json` with 0600 permissions (host-only readable)
- **Backup:** Operator backs up to external location (1Password, encrypted USB, etc.)
- **Plaintext in script:** Unseal script contains keys in plaintext (0700 perms, systemd-only)
- **Mitigation:** Keys are ephemeral; if host compromised, keys must be rotated (Phase 6 escalation to cloud auto-seal)

### Root Token

- **Storage:** `/opt/vault/root-token.txt` (tmpfs, ephemeral, 0600 perms)
- **Lifetime:** Used only for secret seeding (Phase 3 playbook), then deleted
- **Mitigation:** Temporary disk presence reduces exposure window (P1-2)

### Audit Logging

- **Enabled at init:** `vault audit enable file file_path=/var/log/vault/audit.log`
- **All operations logged:** Secret reads/writes, auth attempts, policy changes
- **Retention:** Operator responsible for log rotation (Phase 6: ship logs to SIEM)

## Molecule Testing

Test scenarios (see `molecule/default/`):

1. **Fresh init** — Vault not initialized; role runs init, generates keys, creates systemd service
2. **Idempotent re-run** — Role re-run detects initialization; skips init but creates/updates systemd service
3. **Vault already unsealed** — Unseal script detects unsealed state; exits cleanly (idempotent)

## Troubleshooting

### "Vault API did not become ready"

- **Cause:** Vault container taking too long to start (network latency, slow boot)
- **Solution:** Increase `vault_unseal_retry_max_attempts` or `vault_unseal_retry_wait_seconds`
- **Example:** `-e vault_unseal_retry_max_attempts=20 vault_unseal_retry_wait_seconds=60`

### "Unseal keys not found"

- **Cause:** Role ran but unseal keys weren't stored (disk full, permission denied)
- **Solution:** Check disk space, verify `/opt/vault/` ownership (vault:vault)
- **Recovery:** Delete Vault storage and re-run Phase 3

### "Vault is still sealed after unsealing"

- **Cause:** Unseal keys incorrect, threshold mismatch, or Vault configuration issue
- **Solution:** Check Vault logs: `docker logs vault`
- **Manual fix:** Re-run unseal script: `/opt/vault/unseal.sh` (can be run multiple times safely)

### "Auto-unseal service fails on restart"

- **Cause:** Vault container not started before unseal service tries to run
- **Solution:** Update `After=` in systemd service to ensure Vault container starts first
- **Manual workaround:** Restart both: `systemctl restart vault && systemctl start vault-auto-unseal`

## References

- Vernify Phase 3-5 Architecture (Section 3.2, 11 — init_and_unseal role, auto-unseal pattern)
- Referee Decision (P0-3, P1-1, P1-2, P1-6, P1-8, P1-9 findings)
- [Vault Operator Init](https://www.vaultproject.io/docs/commands/operator/init)
- [Vault Shamir Seal](https://www.vaultproject.io/docs/concepts/seal#shamir)
- [Vault Audit Logging](https://www.vaultproject.io/docs/audit)

## Related Roles

- **blueprints.vault.container_server** — Deploy Vault container (prerequisite)
- **blueprints.vault_access** — Seed secrets + create AppRoles (called after unseal)
- **blueprints.step_ca.container_server** — Deploy step-ca (prerequisite for TLS)
