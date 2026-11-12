#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
S=$ROOT/start.sh
d() { env -i PATH="$PATH" HOME=/nonexistent "$@" "$S" ; }
SECRET=s3cr3t-token-xyz

out=$(env -i PATH="$PATH" CF_API_TOKEN=$SECRET "$S" mybox --dry-run)
assert_contains name "$out" "--name devbox-tls-mybox"
assert_contains net "$out" "--network devbox-net"
assert_contains pub "$out" "-p 127.0.0.1:443:443"
assert_contains vol "$out" "-v devbox-tls-certs:/data"
assert_contains target "$out" "-e TARGET=mybox"
assert_contains ports "$out" "-e PORTS=443:80"
assert_contains redacted "$out" "CF_API_TOKEN=<redacted>"
assert_not_contains secret "$out" "$SECRET"
assert_not_contains no-0000 "$out" "0.0.0.0"

out=$(env -i PATH="$PATH" CF_API_TOKEN=$SECRET "$S" other --ports 8443:3000,5173,8000-8001 --dry-run)
for p in 8443 5173 8000 8001; do assert_contains pub$p "$out" "-p 127.0.0.1:$p:$p"; done
assert_not_contains notmapped "$out" "-p 127.0.0.1:3000"
assert_contains ports2 "$out" "-e PORTS=8443:3000,5173,8000-8001"
assert_contains build "$out" "docker build -t devbox-tls-proxy ."
out=$(env -i PATH="$PATH" CF_API_TOKEN=$SECRET "$S" other --no-build --dry-run)
assert_not_contains nobuild "$out" "docker build"

# .env loading; env/flag take precedence over .env
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp "$ROOT"/{start.sh,gen-caddyfile.sh} "$T"/
printf 'CF_API_TOKEN=%s\nPORTS=9000\nDOMAIN=env.example.org\nACME_CA=https://acme-staging-v02.api.letsencrypt.org/directory\nDOCKER="sudo docker"\n' "$SECRET" > "$T/.env"
out=$(env -i PATH="$PATH" "$T/start.sh" box --dry-run)
assert_contains env-port "$out" "-p 127.0.0.1:9000:9000"
assert_contains env-acme "$out" "-e ACME_CA=https://acme-staging"
assert_contains env-docker "$out" "sudo docker run -d"
assert_not_contains env-secret "$out" "$SECRET"
out=$(env -i PATH="$PATH" PORTS=7000 "$T/start.sh" box --ports 7001 --dry-run)
assert_contains flag-wins "$out" "-p 127.0.0.1:7001:7001"
out=$(env -i PATH="$PATH" PORTS=7000 "$T/start.sh" box --dry-run)
assert_contains env-wins "$out" "-p 127.0.0.1:7000:7000"

run_fail no-target "no target" env -i PATH="$PATH" CF_API_TOKEN=t "$S" --dry-run
run_fail no-token "CF_API_TOKEN is required" env -i PATH="$PATH" "$S" box --dry-run
run_fail bad-ports "invalid port" env -i PATH="$PATH" CF_API_TOKEN=t "$S" box --ports x --dry-run
run_fail dup-ports "duplicate listen port" env -i PATH="$PATH" CF_API_TOKEN=t "$S" box --ports 443,443:81 --dry-run
run_fail bad-opt "unknown option" env -i PATH="$PATH" CF_API_TOKEN=t "$S" box --nope
assert_eq stop "$("$ROOT/stop.sh" box --dry-run)" "docker rm -f devbox-tls-box"
finish
