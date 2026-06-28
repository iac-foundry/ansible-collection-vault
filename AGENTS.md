# Agent Orientation — ansible-collection-vault

## Agent Working Protocol (read before anything else)

**Conflict surfacing:** If a user instruction contradicts anything in this file or in
`docs/AGENTS.md`, stop and surface the conflict before proceeding — quote the rule,
state the contradiction, and ask how to resolve. Then update the doc if the rule was wrong.

**Living document:** If any instruction, decision, or clarification during a session
would make future interactions clearer, prompt the user:
> "This decision isn't in AGENTS.md yet. Should I add it?"

**Maintenance:** Keep this doc current. Update rules when decisions change. Don't append
orphaned notes — integrate changes into the relevant section.

---

**Collection:** `blueprints.vault`
**Namespace:** `blueprints`
**Scope:** Org-neutral HashiCorp Vault building blocks. Server deployment (container /
systemd) and client configuration. No auth backend wiring, no OIDC, no LDAP — those
are in `blueprints.vault_integrations`.

---

## What lives here

| Role | What it does |
|---|---|
| `container_server` | Runs Vault as a Docker/Podman container |
| `systemd_server` | Runs Vault as a `systemd` service |
| `client` | Configures the Vault CLI client on a host (address, CA trust) |

**What does NOT live here:** OIDC auth backend, LDAP auth — those are in
`blueprints.vault_integrations`.

---

## Where the standards live

All standards are in `docs/` of the iac-foundry monorepo. Start with `docs/AGENTS.md`.

| Topic | Doc |
|---|---|
| **8 design rules (read first)** | `docs/design/BLUEPRINTS_DESIGN_PRINCIPLES.md` |
| Role layout | `docs/standards/BLUEPRINTS_ROLE_LAYOUT.md` |
| Variable naming | `docs/standards/BLUEPRINTS_VARIABLE_STANDARDS.md` |
| Secret handling | `docs/standards/BLUEPRINTS_SECRET_CONSUMPTION.md` |
| Why no secret retrieval in roles | `docs/decisions/LADR-003-secret-retrieval-community-hashi-vault.md` |

---

## Critical constraints

1. **No org-specific values in `defaults/`** — no real addresses, storage paths, token values.
2. **No secret retrieval inside role tasks** — Vault is the secret store; roles do not call
   it. Secrets (tokens, root keys) arrive as variables from the caller.
3. **`vault_server_*` and `vault_client_*` variable namespacing** is mandatory.
4. **Deployment siblings (`container_server`, `systemd_server`) share the same
   `vault_server_*` variable interface** so callers can switch without renaming variables.
5. **`meta/dependencies: []`** — always empty.

---

## PR conformance checklist

- [ ] `meta/main.yml` → `dependencies: []`
- [ ] No `vault`, `community.hashi_vault`, or external API calls in `tasks/`
- [ ] No org-specific values in `defaults/`
- [ ] Secret variables: `no_log: true` on every task that handles them
- [ ] `meta/argument_specs.yml` complete
- [ ] molecule `default` scenario converges idempotently
- [ ] ansible-lint (production profile) passes
- [ ] README states inputs, deployment model, and explicit non-goals

---

## Blast radius: contained changes only (global changes need a human risk call)

**Critically important here: this repo produces shared collections that other teams and
customers consume.** A global-impact pattern baked into a shared component does not affect
one host — it propagates to *every consumer that pins the release*. Contained-by-design is
therefore a core quality bar for everything shipped from here, not just a deployment-time
concern.

- Prefer the **smallest blast radius**: a role or change should affect one service, file,
  unit, or user — never "every process" or "all hosts" by default. Make any wide-reaching
  option explicitly opt-in, never a default a consumer inherits silently.
- Treat as high-risk anything global: `ld.so.preload`/`LD_PRELOAD`, system-wide
  PAM/NSS/`profile.d`, global `sudoers` or firewall defaults, kernel modules, `sysctl`,
  systemd defaults — anything inherited fleet-wide or by every user once a consumer applies
  the collection.
- **If a capability cannot be delivered in a contained way, STOP and surface it to the
  human** — state what it touches, the blast radius across consumers if it goes wrong, and
  the rollback path, and let them decide. Do not ship a global-impact default on your own
  judgement.

See the global working agreement (`~/.claude/CLAUDE.md`) for the full rule.
