#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
cp /home/openclaw/.openclaw/config.json "${REPO_ROOT}/backups/config-${TS}.json"
cd "${REPO_ROOT}"
git add backups/config-${TS}.json
if ! git diff --cached --quiet; then
  git commit -m "backup: daily config snapshot ${TS}" || true
  git push origin HEAD || true
fi
