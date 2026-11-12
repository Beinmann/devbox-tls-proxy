#!/usr/bin/env bash
# Runs all tests; needs neither Docker nor Caddy.
cd "$(dirname "$0")" || exit 1
rc=0
for t in test_*.sh; do bash "$t" || rc=1; done
if command -v shellcheck >/dev/null; then
  shellcheck -x ../*.sh ./*.sh && echo "shellcheck: ok" || rc=1
else
  echo "shellcheck not installed, skipped"
fi
exit $rc
