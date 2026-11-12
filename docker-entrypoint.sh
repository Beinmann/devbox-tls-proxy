#!/usr/bin/env bash
# Generates the Caddyfile from env and runs Caddy. Fails fast on bad config.
set -euo pipefail
CADDYFILE=/etc/caddy/Caddyfile
/usr/local/bin/gen-caddyfile.sh > "$CADDYFILE" || exit 1
echo "devbox-tls-proxy: generated $CADDYFILE:" >&2
cat "$CADDYFILE" >&2
caddy fmt --overwrite "$CADDYFILE" >/dev/null 2>&1 || true
exec caddy run --config "$CADDYFILE" --adapter caddyfile
