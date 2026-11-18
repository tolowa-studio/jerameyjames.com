#!/usr/bin/env bash
# TOL-655: Vercel is retired and prohibited (runtime is Cloud Run). Fails if Vercel
# config comes back: vercel.json, a .vercel/ directory, vercel.ts or .vercelignore
# (a dangling symlink at any of those paths counts too: -e alone follows the link).
# Usage: scripts/check-no-vercel.sh [root-dir]   (defaults to the repo root)
set -euo pipefail
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
found=0
for p in vercel.json .vercel vercel.ts .vercelignore; do
  if [ -e "$root/$p" ] || [ -L "$root/$p" ]; then
    echo "Vercel residue: $p" >&2
    found=1
  fi
done
if [ "$found" -ne 0 ]; then
  echo "Vercel is retired (TOL-655); remove the files listed above." >&2
  exit 1
fi
echo "ok: no Vercel config in repo"
