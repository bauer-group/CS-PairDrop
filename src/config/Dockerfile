# ═══════════════════════════════════════════════════════════════════════════════
# PairDrop RTC Config Generator - Dockerfile
# ═══════════════════════════════════════════════════════════════════════════════
# Init container that generates rtc_config.json from template using envsubst
#
# Features:
#   - Alpine minimal base image
#   - envsubst for variable substitution
#   - One-shot execution (restart: no)
#
# Build:  docker build -t pairdrop-config .
# Run:    docker run -e TURN_HOSTNAME=turn.example.com -e TURN_SECRET=xxx -v config:/config pairdrop-config
# ═══════════════════════════════════════════════════════════════════════════════

FROM alpine:latest

# =============================================================================
# Custom Labels
# =============================================================================

# Metadata
LABEL vendor="BAUER GROUP"
LABEL maintainer="Karl Bauer <karl.bauer@bauer-group.com>"

# Opencontainers Metadata
LABEL org.opencontainers.image.title="PairDrop Config Generator"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="BAUER GROUP"
LABEL org.opencontainers.image.authors="Karl Bauer <karl.bauer@bauer-group.com>"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.url="https://github.com/bauer-group/CS-PairDrop"
LABEL org.opencontainers.image.documentation="https://github.com/bauer-group/CS-PairDrop#readme"
LABEL org.opencontainers.image.description="Generates RTC config JSON for PairDrop TURN server integration"
LABEL org.opencontainers.image.version="0.0.0"

# =============================================================================
# System Setup
# =============================================================================

# Install envsubst (part of gettext)
RUN apk add --no-cache gettext

# =============================================================================
# Application Setup
# =============================================================================

# Copy template and generator script
COPY rtc_config.template.json /templates/
COPY generate-config.sh /generate-config.sh
RUN chmod +x /generate-config.sh

# =============================================================================
# Runtime Configuration
# =============================================================================

# Output volume for generated config
VOLUME ["/config"]

ENTRYPOINT ["/generate-config.sh"]

# ───────────────────────────────────────────────────────────────────────────────
# Usage
# ───────────────────────────────────────────────────────────────────────────────
# Build:              docker build -t pairdrop-config .
# Run:                docker run -e TURN_HOSTNAME=turn.example.com -e TURN_SECRET=secret -v config:/config pairdrop-config
# Output:             /config/rtc_config.json
