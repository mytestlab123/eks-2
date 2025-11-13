#!/usr/bin/env bash
set -euo pipefail
LOG="/tmp/eks2-smoke.log"
mkdir -p /tmp >/dev/null 2>&1 || true
{
  echo "[smoke] start: $(date -Iseconds)"
  # OS check
  source /etc/os-release || true
  echo "OS: ${NAME:-unknown} ${VERSION_ID:-unknown}"
  if [[ "${NAME:-}" != *"Amazon Linux"* ]]; then echo "warn: not Amazon Linux"; fi

  # Tool presence (no network)
  for t in aws nextflow docker podman just rg fd eza bat jq yq; do
    if command -v "$t" >/dev/null 2>&1; then echo "ok: $t"; else echo "miss: $t"; fi
  done

  # Env footprint (no secrets)
  echo "ENV=${ENV:-unset}"
  echo "OS_VERSION=${OS_VERSION:-unset}"
  echo "NXF_VER=${NXF_VER:-unset}"
  echo "NXF_OFFLINE=${NXF_OFFLINE:-unset}"
  echo "AWS_DEFAULT_PROFILE=${AWS_DEFAULT_PROFILE:-unset}"

  # Repo sanity
  test -f justfile && echo "ok: justfile"
  test -f docs/TASKS.md && echo "ok: docs/TASKS.md"
  test -f issues.md && echo "ok: issues.md"
  test -f offline/justfile && echo "ok: offline/justfile"

  echo "[smoke] done: $(date -Iseconds)"
} | tee "$LOG"
echo "log: $LOG"

