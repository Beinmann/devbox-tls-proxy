#!/usr/bin/env bash
# Stop and remove the proxy container of one devbox container.
#   ./stop.sh <container> [--dry-run]
set -euo pipefail
[[ $# -ge 1 && $1 != -* ]] || { echo "usage: $0 <container> [--dry-run]" >&2; exit 2; }
DOCKER=${DOCKER:-docker}
NAME="devbox-tls-$1"
if [[ ${2:-} == --dry-run ]]; then echo "$DOCKER rm -f $NAME"; exit 0; fi
# shellcheck disable=SC2086
$DOCKER rm -f "$NAME"
echo "==> stopped $NAME (cert volume devbox-tls-certs kept)"
