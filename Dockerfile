# Caddy with the Cloudflare DNS plugin (DNS-01 challenge, so no public
# port 80/443 is needed for the certificate).
ARG CADDY_VERSION=2.10.0
# Images are pinned by tag AND digest (the tag is for humans, the digest is
# what is pulled). To bump: look up the new digest (e.g. `docker buildx
# imagetools inspect caddy:<tag>`), update the version and both digests.
ARG CADDY_BUILDER_DIGEST=sha256:fe8d0d6cdbfd382197c4d715ffd5b41210165e2f64a81ce546ae63eeef35873a
ARG CADDY_RUNTIME_DIGEST=sha256:133b5eb7ef9d42e34756ba206b06d84f4e3eb308044e268e182c2747083f09de

FROM caddy:${CADDY_VERSION}-builder@${CADDY_BUILDER_DIGEST} AS builder
# The plugin has no regular release tags, so it is pinned to a commit via a Go
# pseudo-version: v0.0.0-<UTC commit time yyyymmddhhmmss>-<12-char sha>.
# This one is caddy-dns/cloudflare a8737d095ad5 (2026-03-23). To bump, take the
# newest commit of the master branch and rebuild the pseudo-version.
ARG CF_PLUGIN_VERSION=v0.0.0-20260323191214-a8737d095ad5
RUN xcaddy build --with github.com/caddy-dns/cloudflare@${CF_PLUGIN_VERSION}

FROM caddy:${CADDY_VERSION}@${CADDY_RUNTIME_DIGEST}
RUN apk add --no-cache bash
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY gen-caddyfile.sh docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/gen-caddyfile.sh /usr/local/bin/docker-entrypoint.sh
# Caddy's state dirs (the base image sets the same values); with --read-only
# only /data (volume) and the tmpfs mounts /config, /etc/caddy, /tmp are writable.
ENV XDG_CONFIG_HOME=/config XDG_DATA_HOME=/data
# Certificates/ACME account live in /data: mount the shared volume there.
VOLUME /data
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
