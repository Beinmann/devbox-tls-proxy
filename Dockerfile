# Caddy with the Cloudflare DNS plugin (DNS-01 challenge, so no public
# port 80/443 is needed for the certificate).
ARG CADDY_VERSION=2.10.0

FROM caddy:${CADDY_VERSION}-builder AS builder
# The plugin has no regular release tags; override with a pseudo-version
# (e.g. --build-arg CF_PLUGIN_VERSION=v0.0.0-2025...) to pin it exactly.
ARG CF_PLUGIN_VERSION=master
RUN xcaddy build --with github.com/caddy-dns/cloudflare@${CF_PLUGIN_VERSION}

FROM caddy:${CADDY_VERSION}
RUN apk add --no-cache bash
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY gen-caddyfile.sh docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/gen-caddyfile.sh /usr/local/bin/docker-entrypoint.sh
# Certificates/ACME account live in /data: mount the shared volume there.
VOLUME /data
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
