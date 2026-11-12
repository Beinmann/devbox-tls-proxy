# tiny test helpers
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; [[ -z ${2:-} ]] || echo "$2" | sed 's/^/    /' >&2; }
# assert_contains NAME HAYSTACK NEEDLE
assert_contains() { if [[ $2 == *"$3"* ]]; then ok; else bad "$1: missing '$3'" "$2"; fi; }
assert_not_contains() { if [[ $2 != *"$3"* ]]; then ok; else bad "$1: unexpected '$3'" "$2"; fi; }
assert_eq() { if [[ $2 == "$3" ]]; then ok; else bad "$1: expected '$3' got '$2'"; fi; }
# run_fail NAME ERRSUBSTR cmd... : must exit non-zero, stderr containing substring
run_fail() {
  local name=$1 sub=$2; shift 2
  local out rc=0
  out=$("$@" 2>&1 >/dev/null) || rc=$?
  if (( rc != 0 )); then assert_contains "$name" "$out" "$sub"; else bad "$name: expected failure"; fi
}
finish() { echo "$(basename "$0"): $PASS passed, $FAIL failed"; (( FAIL == 0 )); }
