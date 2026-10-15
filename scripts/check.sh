#!/usr/bin/env bash
# One command for all checks, as in CI: pub get, format, analyze (infos fail), test, stray files.
set -euo pipefail
cd "$(dirname "$0")/../dkc"

names=(); results=()
step() { local n="$1"; shift; echo "== $n"; if "$@"; then results+=(pass); else results+=(FAIL); fi; names+=("$n"); }
stray() { local f; f=$(find . \( -name .git -o -name build -o -name .dart_tool -o -name Pods \) -prune -o \
  \( -name '*.orig' -o -name '*.rej' -o -name '*.bak' -o -name '*-e' -o -name .DS_Store \) -type f -print); [ -z "$f" ] || { echo "$f"; return 1; }; }

step pub-get flutter pub get
step format dart format --output=none --set-exit-if-changed .
step analyze flutter analyze
step test flutter test
step stray-files stray

echo; printf '%-12s | %s\n' step result
fail=0
for i in "${!names[@]}"; do printf '%-12s | %s\n' "${names[$i]}" "${results[$i]}"; [ "${results[$i]}" = pass ] || fail=1; done
exit $fail
