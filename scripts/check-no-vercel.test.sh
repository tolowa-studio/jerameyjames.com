#!/usr/bin/env bash
# TOL-655: proves check-no-vercel.sh fails on each kind of residue and passes on a clean tree.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
check="$here/check-no-vercel.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/novercel-XXXX")"
trap 'rm -rf "$tmp"' EXIT

"$check" "$tmp" >/dev/null || { echo "FAIL: clean tree rejected" >&2; exit 1; }

for residue in vercel.json vercel.ts .vercelignore; do
  touch "$tmp/$residue"
  if "$check" "$tmp" >/dev/null 2>&1; then echo "FAIL: $residue not caught" >&2; exit 1; fi
  rm "$tmp/$residue"
done
# a dangling symlink must not slip through (-e follows the link and sees nothing)
ln -s does-not-exist "$tmp/vercel.json"
if "$check" "$tmp" >/dev/null 2>&1; then echo "FAIL: dangling vercel.json symlink not caught" >&2; exit 1; fi
rm "$tmp/vercel.json"
mkdir "$tmp/.vercel"
if "$check" "$tmp" >/dev/null 2>&1; then echo "FAIL: .vercel/ not caught" >&2; exit 1; fi
rmdir "$tmp/.vercel"

# the real repo must be clean too
"$check" >/dev/null || { echo "FAIL: repo has Vercel residue" >&2; exit 1; }
echo "ok: check-no-vercel catches vercel.json, vercel.ts, .vercelignore, .vercel/, dangling symlinks"
