#!/usr/bin/env bash
# Start a TLS-terminating proxy container for one devbox container.
#   ./start.sh <container> [--ports SPEC] [--dry-run] [--no-build]
# Config comes from ./.env (gitignored) and the environment; see README.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() { echo "usage: $0 <container> [--ports SPEC] [--dry-run] [--no-build]" >&2; exit 2; }

# .env must not override variables already set in the environment
vars=(TARGET PORTS DOMAIN ACME_CA HOST_HEADER CF_API_TOKEN DOCKER)
declare -A pre=()
for v in "${vars[@]}"; do [[ -z ${!v+x} ]] || pre[$v]=${!v}; done
if [[ -f .env ]]; then set -a; . ./.env; set +a; fi
for v in "${!pre[@]}"; do export "$v=${pre[$v]}"; done

DRY=0; BUILD=1; ARG_TARGET=""; ARG_PORTS=""
while (( $# )); do
  case $1 in
    --dry-run) DRY=1 ;;
    --no-build) BUILD=0 ;;
    --ports) [[ $# -ge 2 ]] || usage; ARG_PORTS=$2; shift ;;
    --ports=*) ARG_PORTS=${1#--ports=} ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [[ -z $ARG_TARGET ]] || usage; ARG_TARGET=$1 ;;
  esac
  shift
done
[[ -z $ARG_TARGET ]] || TARGET=$ARG_TARGET
[[ -z $ARG_PORTS ]] || PORTS=$ARG_PORTS
export TARGET=${TARGET:-} PORTS=${PORTS:-443:80} DOMAIN=${DOMAIN:-localhost.rdrkolaq.de}
export HOST_HEADER=${HOST_HEADER:-original} ACME_CA=${ACME_CA:-} CF_API_TOKEN=${CF_API_TOKEN:-}
[[ -n $TARGET ]] || { echo "error: no target container given" >&2; usage; }

# Validate everything (TARGET, token, PORTS, duplicates) with the generator.
pairs=$(./gen-caddyfile.sh --list-ports) || exit 1

DOCKER=${DOCKER:-docker}
NAME="devbox-tls-$TARGET"
NET=devbox-net
VOLUME=devbox-tls-certs
IMAGE=devbox-tls-proxy

publish=()
while read -r l _; do publish+=(-p "127.0.0.1:$l:$l"); done <<< "$pairs"

run_args=(run -d --name "$NAME" --network "$NET" "${publish[@]}"
  -v "$VOLUME:/data"
  # Hardening: no capabilities except binding low ports, read-only rootfs
  # (writable: /data volume + tmpfs for the generated Caddyfile, Caddy's
  # autosave under /config, and /tmp), resource limits. No restart policy.
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE --security-opt no-new-privileges
  --read-only --tmpfs /etc/caddy --tmpfs /tmp --tmpfs /config
  --memory 256m --pids-limit 256
  -e "TARGET=$TARGET" -e "PORTS=$PORTS" -e "DOMAIN=$DOMAIN" -e "HOST_HEADER=$HOST_HEADER")
[[ -z $ACME_CA ]] || run_args+=(-e "ACME_CA=$ACME_CA")
# The token goes through an env-file on stdin: never in argv or `docker inspect`
# of the command line, and it also survives `sudo docker`.
run_args+=(--env-file /dev/stdin "$IMAGE")

if (( DRY )); then
  # shellcheck disable=SC2086
  {
    (( BUILD )) && echo "$DOCKER build -t $IMAGE ."
    echo "$DOCKER network create $NET   # only if it does not exist"
    echo "$DOCKER volume create $VOLUME   # only if it does not exist"
    echo "$DOCKER rm -f $NAME   # only if a leftover exists"
    echo "printf 'CF_API_TOKEN=<redacted>' | $DOCKER ${run_args[*]}"
  }
  exit 0
fi

# shellcheck disable=SC2086
{
  $DOCKER network inspect "$NET" >/dev/null 2>&1 || $DOCKER network create "$NET" >/dev/null
  $DOCKER volume inspect "$VOLUME" >/dev/null 2>&1 || $DOCKER volume create "$VOLUME" >/dev/null
  (( BUILD == 0 )) || $DOCKER build -t "$IMAGE" .
  $DOCKER rm -f "$NAME" >/dev/null 2>&1 || true
  printf 'CF_API_TOKEN=%s\n' "$CF_API_TOKEN" | $DOCKER "${run_args[@]}" >/dev/null
}
echo "==> $NAME: proxying to $TARGET (first start issues the certificate, ~1 min; see: $DOCKER logs -f $NAME)"
while read -r l t; do echo "    https://$DOMAIN:$l -> $TARGET:$t"; done <<< "$pairs"
