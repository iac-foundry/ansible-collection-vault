#!/usr/bin/env bash
#
# Blueprints "no hidden dependencies" CI guard.
#
# Enforces BLUEPRINTS_DESIGN_PRINCIPLES.md §1 and §2 on COMPONENT collections:
#   - a component role must not include/import another blueprints collection (§1)
#   - a component role must not retrieve secrets or query external systems (§2)
#
# Integration collections (name ending in _integrations) are exempt from the
# "knows about another product" check, but are STILL forbidden from retrieving
# secrets — they receive them as variables.
#
# Usage:  ci/no_hidden_deps_guard.sh [collections_root]
# Exit:   0 = clean, 1 = violation(s) found.
#
# POSIX/bash-3.2 compatible (macOS default shell).

set -eu

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0

# Patterns that indicate runtime secret retrieval / discovery inside a role's tasks.
# Applies to ALL collections (components and integrations).
SECRET_PATTERNS='
community\.hashi_vault
lookup\([[:space:]]*['"'"'"]?(community\.hashi_vault|hashi_vault)
\bvault\b[[:space:]]+(kv|read|login|write)
ansible\.builtin\.(command|shell):.*vault
'

# Cross-collection composition inside a component role. COMPONENT collections only.
CROSS_PATTERNS='
(include_role|import_role).*blueprints\.
'

scan_dir() {
  # $1 = label, $2 = dir, $3 = newline-separated patterns
  label="$1"; dir="$2"; patterns="$3"
  printf '%s\n' "$patterns" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    hits="$(grep -REn "$p" "$dir" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
      echo "VIOLATION ($label): pattern /$p/"
      echo "$hits"
    fi
  done
}

violations=0
for coll in "$ROOT"/*/; do
  name="$(basename "$coll")"
  [ -d "${coll}roles" ] || continue
  for td in "${coll}"roles/*/tasks; do
    [ -d "$td" ] || continue

    out="$(scan_dir "secret-retrieval in $name" "$td" "$SECRET_PATTERNS")"
    if [ -n "$out" ]; then echo "$out"; violations=1; fi

    case "$name" in
      *_integrations) : ;;  # exempt from cross-product knowledge
      *)
        out="$(scan_dir "cross-collection in $name" "$td" "$CROSS_PATTERNS")"
        if [ -n "$out" ]; then echo "$out"; violations=1; fi
        ;;
    esac
  done
done

if [ "$violations" -ne 0 ]; then
  echo ""
  echo "FAILED: hidden-dependency violations found (see BLUEPRINTS_DESIGN_PRINCIPLES.md §1/§2)."
  exit 1
fi
echo "OK: no hidden-dependency violations."
