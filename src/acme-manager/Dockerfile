# ═══════════════════════════════════════════════════════════════════════════════
# PairDrop ACME Manager - Dockerfile
# ═══════════════════════════════════════════════════════════════════════════════
# Let's Encrypt certificate manager for Coturn TURN server
#
# Features:
#   - Alpine minimal base image
#   - Lego ACME client for certificate management
#   - Automatic certificate renewal
#   - Docker socket access for Coturn reload
#   - Info page on port 80
#
# Build:  docker build -t pairdrop-acme .
# Run:    docker run -p 80:80 -v certs:/certs -v /var/run/docker.sock:/var/run/docker.sock:ro pairdrop-acme
# ═══════════════════════════════════════════════════════════════════════════════

FROM alpine:latest

# =============================================================================
# Build Arguments
# =============================================================================

ARG LEGO_VERSION=4.21.0

# =============================================================================
# Custom Labels
# =============================================================================

# Metadata
LABEL vendor="BAUER GROUP"
LABEL maintainer="Karl Bauer <karl.bauer@bauer-group.com>"

# Opencontainers Metadata
LABEL org.opencontainers.image.title="PairDrop ACME Manager"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="BAUER GROUP"
LABEL org.opencontainers.image.authors="Karl Bauer <karl.bauer@bauer-group.com>"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.url="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.documentation="https://github.com/bauer-group/CS-PairDrop#readme"
LABEL org.opencontainers.image.description="Let's Encrypt certificate manager for PairDrop Coturn TURN server"
LABEL org.opencontainers.image.version="0.0.0"

# =============================================================================
# System Setup
# =============================================================================

# System dependencies
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    docker-cli \
    busybox-extras

# =============================================================================
# Application Setup
# =============================================================================

# Install Lego ACME client
ADD https://github.com/go-acme/lego/releases/download/v${LEGO_VERSION}/lego_v${LEGO_VERSION}_linux_amd64.tar.gz /tmp/lego.tar.gz
RUN tar -xzf /tmp/lego.tar.gz -C /usr/local/bin lego && \
    rm /tmp/lego.tar.gz && \
    chmod +x /usr/local/bin/lego

# Web root for info page and ACME challenge
RUN mkdir -p /var/www/.well-known/acme-challenge

# Copy application files
COPY www/ /var/www/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# =============================================================================
# Runtime Configuration
# =============================================================================

# Certificate output volume
VOLUME ["/certs"]

# HTTP port for ACME challenge and info page
EXPOSE 80/tcp

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:80/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]

# ───────────────────────────────────────────────────────────────────────────────
# Usage
# ───────────────────────────────────────────────────────────────────────────────
# Build:              docker build -t pairdrop-acme .
# Run:                docker run -p 80:80 -v certs:/certs -v /var/run/docker.sock:/var/run/docker.sock:ro pairdrop-acme
# Environment:        ACME_DOMAIN, ACME_EMAIL, COTURN_CONTAINER_NAME
# Certificates:       Output to /certs/live/${ACME_DOMAIN}/
