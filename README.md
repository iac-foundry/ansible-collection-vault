# blueprints.vault

Reusable, org-agnostic HashiCorp Vault building blocks (no hidden dependencies).

**No hidden dependencies.** This collection assumes no other `blueprints` collection exists and
queries no external system at runtime. All configuration and secrets are caller-supplied variables.
See [../../docs/design/BLUEPRINTS_DESIGN_PRINCIPLES.md](../../docs/design/BLUEPRINTS_DESIGN_PRINCIPLES.md).

## Roles

See `roles/`. Each role README states its inputs, deployment model, and non-goals.
