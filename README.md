# ansible-collection-vault

Ansible source repository for the `blueprint.vault` collection.

## Initial scope

- Runtime preflight role for deterministic Vault execution checks.
- Future `vault_kv` lookup implementation aligned to AKB Vault roadmap.

## Design constraints

- Multi-org reusable defaults.
- Fail-fast behavior.
- No hardcoded organization endpoints or secret paths in defaults.
