#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
GEN=$ROOT/gen-caddyfile.sh
g() { env -i PATH="$PATH" CF_API_TOKEN=tok TARGET=box "$@" "$GEN"; }
ports() { env -i PATH="$PATH" CF_API_TOKEN=tok TARGET=box "$@" "$GEN" --list-ports | tr '\n' ';'; }

assert_eq default "$(ports)" "443 80;"
assert_eq bare "$(ports PORTS=3000)" "3000 3000;"
assert_eq mapped "$(ports PORTS=443:3000)" "443 3000;"
assert_eq mixed "$(ports PORTS=443:3000,5173,8000-8002)" "443 3000;5173 5173;8000 8000;8001 8001;8002 8002;"
assert_eq spaces "$(ports 'PORTS= 443:3000 , 5173 ')" "443 3000;5173 5173;"
assert_eq rangepair "$(ports PORTS=9000-9001:80-81)" "9000 80;9001 81;"
assert_eq single-range "$(ports PORTS=7-7)" "7 7;"

run_fail dup "duplicate listen port 443" env PORTS=443:80,443:81 bash -c 'env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=$PORTS "$0"' "$GEN"
run_fail dup-range "duplicate listen port 8001" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=8000-8002,8001 "$GEN"
run_fail letters "invalid port" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=abc "$GEN"
run_fail zero "out of range" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=0 "$GEN"
run_fail big "out of range" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=443:70000 "$GEN"
run_fail desc "descending" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=10-5 "$GEN"
run_fail empty-entry "empty entry" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=80,,81 "$GEN"
run_fail lenmismatch "range lengths differ" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=1-3:5-6 "$GEN"
run_fail threecolon "invalid entry" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b PORTS=1:2:3 "$GEN"
run_fail no-target "TARGET is required" env -i PATH="$PATH" CF_API_TOKEN=t "$GEN"
run_fail bad-target "invalid TARGET" env -i PATH="$PATH" CF_API_TOKEN=t 'TARGET=a b;x' "$GEN"
run_fail no-token "CF_API_TOKEN is required" env -i PATH="$PATH" TARGET=b "$GEN"
run_fail bad-acme "invalid ACME_CA" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b ACME_CA=nonsense "$GEN"
run_fail bad-hh "HOST_HEADER" env -i PATH="$PATH" CF_API_TOKEN=t TARGET=b HOST_HEADER=x "$GEN"

out=$(g)
assert_contains single "$out" "localhost.rdrkolaq.de:443 {"
assert_contains single-tls "$out" "dns cloudflare {env.CF_API_TOKEN}"
assert_contains single-rp "$out" "reverse_proxy box:80 {"
assert_contains flush "$out" "flush_interval -1"
assert_contains noredirect "$out" "auto_https disable_redirects"
assert_not_contains notoken "$out" "tok"$'\n'
assert_not_contains no-acme "$out" "acme_ca"
assert_not_contains no-hostup "$out" "header_up"
assert_eq one-block "$(grep -c 'reverse_proxy' <<<"$out")" 1

out=$(g PORTS=443:3000,5173 DOMAIN=x.example.org ACME_CA=https://acme-staging-v02.api.letsencrypt.org/directory HOST_HEADER=target)
assert_contains multi1 "$out" "x.example.org:443 {"
assert_contains multi2 "$out" "x.example.org:5173 {"
assert_contains multi-rp1 "$out" "reverse_proxy box:3000 {"
assert_contains multi-rp2 "$out" "reverse_proxy box:5173 {"
assert_contains acme "$out" "acme_ca https://acme-staging-v02.api.letsencrypt.org/directory"
assert_contains hostup "$out" "header_up Host {upstream_hostport}"
assert_eq two-blocks "$(grep -c 'reverse_proxy' <<<"$out")" 2
finish
