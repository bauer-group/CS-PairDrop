# ═══════════════════════════════════════════════════════════════════════════════
# PairDrop Coturn TURN Server - Dockerfile
# ═══════════════════════════════════════════════════════════════════════════════
# TURN/STUN server for WebRTC NAT traversal with TLS support
#
# Features:
#   - Official Coturn base image
#   - TLS certificate support (Let's Encrypt)
#   - TURN REST API authentication
#   - Health check endpoint
#
# Build:  docker build -t pairdrop-coturn .
# Run:    docker run -p 3478:3478 -p 5349:5349 -v certs:/certs pairdrop-coturn
# ═══════════════════════════════════════════════════════════════════════════════

FROM coturn/coturn:latest

# =============================================================================
# Custom Labels
# =============================================================================

# Metadata
LABEL vendor="BAUER GROUP"
LABEL maintainer="Karl Bauer <karl.bauer@bauer-group.com>"

# Opencontainers Metadata
LABEL org.opencontainers.image.title="PairDrop Coturn TURN Server"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="BAUER GROUP"
LABEL org.opencontainers.image.authors="Karl Bauer <karl.bauer@bauer-group.com>"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.url="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.documentation="https://github.com/bauer-group/CS-PairDrop#readme"
LABEL org.opencontainers.image.description="TURN/STUN server for PairDrop WebRTC NAT traversal"
LABEL org.opencontainers.image.version="0.0.0"

# =============================================================================
# Runtime Configuration
# =============================================================================

# STUN/TURN ports
EXPOSE 3478/tcp 3478/udp

# TURNS (TLS) ports
EXPOSE 5349/tcp 5349/udp

# Certificate volume (Let's Encrypt)
VOLUME ["/certs"]

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD turnadmin -l -N localhost || exit 1

# ───────────────────────────────────────────────────────────────────────────────
# Usage
# ───────────────────────────────────────────────────────────────────────────────
# Build:              docker build -t pairdrop-coturn .
# Run:                docker run -p 3478:3478/udp -p 5349:5349/tcp -v certs:/certs:ro pairdrop-coturn
# Config:             Mount turnserver.conf to /etc/coturn/turnserver.conf
# Certs:              Mount Let's Encrypt certs to /certs
