# PairDrop Self-Hosting Stack - Konzept

> **BAUER GROUP** | CS-PairDrop
> Professioneller Self-Hosting Stack für PairDrop mit Coturn TURN Server

---

## 1. Executive Summary

### Ziel
Aufbau eines produktionsreifen, eigengehosteten **PairDrop File-Sharing Stacks** mit dediziertem **Coturn TURN Server** und **automatischer Let's Encrypt Zertifikatsverwaltung**.

### Kernprinzipien
- **Saubere Trennung der Zuständigkeiten** (ACME Manager, Coturn, PairDrop)
- **Kontrollierte Zertifikatsverwaltung** (nicht Traefik-terminiert für TURN)
- **Reproduzierbare Automatisierung** (GitOps-tauglich)
- **Drei Deployment-Modi** (Development, Traefik, Coolify)

---

## 2. Architektur

### 2.1 Komponenten-Übersicht

```
                    ┌─────────────────────────────────────────┐
                    │              INTERNET                   │
                    └─────────────┬───────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────────┐
          │                       │                           │
          ▼                       ▼                           ▼
    ┌───────────┐          ┌───────────┐              ┌───────────┐
    │  Traefik  │          │   ACME    │              │  Coturn   │
    │  (HTTPS)  │          │  Manager  │              │  (TURN)   │
    │  :443     │          │  :80      │              │  :3478    │
    └─────┬─────┘          │  (ACME)   │              │  :5349    │
          │                └─────┬─────┘              │  :10000-  │
          │                      │                    │   20000   │
          ▼                      ▼                    └─────┬─────┘
    ┌───────────┐          ┌───────────┐                    │
    │ PairDrop  │          │  Shared   │◄───────────────────┘
    │  :3000    │          │  Certs    │
    └───────────┘          │  Volume   │
                           └───────────┘
```

### 2.2 Traffic-Flows

| Protokoll | Port(s) | Service | TLS Termination |
|-----------|---------|---------|-----------------|
| HTTPS | 443 | Traefik → PairDrop | Traefik |
| HTTP | 80 | ACME Challenge | ACME Manager |
| STUN/TURN | 3478 (TCP/UDP) | Coturn | - |
| TURNS | 5349 (TCP/UDP) | Coturn | Coturn (selbst) |
| Media Relay | 10000-20000 (UDP) | Coturn | - |

### 2.3 Komponenten-Verantwortlichkeiten

| Komponente | Verantwortung |
|------------|---------------|
| **PairDrop** | Web UI, WebRTC Signaling, File Transfer |
| **Coturn** | STUN/TURN Server für NAT Traversal, TLS selbst terminiert |
| **ACME Manager** | Let's Encrypt Zertifikate holen/erneuern |
| **Traefik** | Reverse Proxy für PairDrop (HTTPS), ACME Passthrough für TURN |
| **Shared Volume** | Zertifikate zwischen ACME Manager und Coturn |

### 2.4 Unterschied zum Dashboard-Template

> **Wichtig:** Im Gegensatz zum CS-Dashboard (gethomepage) mit dem "baked config" Bug können bei PairDrop alle Konfigurationen **zur Laufzeit per Volume gemountet** werden.

| Aspekt | CS-Dashboard | CS-PairDrop |
|--------|--------------|-------------|
| Config-Handling | Baked ins Image (Bug) | Runtime Volume Mount |
| Image-Build | Immer bei Config-Änderung | Nur bei Dockerfile-Änderung |
| Flexibilität | Rebuild nötig | Hot-Reload möglich |
| CI/CD | Build + Push | Nur Config-Update |

### 2.5 Deployment-Modi & Profile

Jede Compose-Datei unterstützt **zwei Modi** via Docker Compose Profiles:

| Modus | Profil | Services | Transfer-Methode |
|-------|--------|----------|------------------|
| **Mit TURN** | `--profile turn` | PairDrop + Coturn + ACME | P2P via TURN (NAT Traversal) |
| **Ohne TURN** | (default) | Nur PairDrop | WebSocket Fallback |

**Deployment-Befehle:**

```bash
# ─────────────────────────────────────────────────────────────
# OHNE TURN (WebSocket Fallback) - Default
# ─────────────────────────────────────────────────────────────
docker compose -f docker-compose.development.yml up -d
docker compose -f docker-compose.traefik.yml up -d
docker compose -f docker-compose.coolify.yml up -d

# ─────────────────────────────────────────────────────────────
# MIT TURN (eigener TURN Server)
# ─────────────────────────────────────────────────────────────
docker compose -f docker-compose.development.yml --profile turn up -d
docker compose -f docker-compose.traefik.yml --profile turn up -d
docker compose -f docker-compose.coolify.yml --profile turn up -d
```

**Entscheidungshilfe:**

```
Brauchst du NAT Traversal (verschiedene Netzwerke)?
    │
    ├─► Nein → Ohne Profil (WebSocket Fallback)
    │          Geräte müssen im selben Netzwerk sein
    │
    └─► Ja → Mit --profile turn
              Eigener TURN Server mit Let's Encrypt TLS
```

**Wichtig:** Ohne TURN wird `WS_FALLBACK=true` benötigt - Traffic läuft dann über den Server (nicht E2E verschlüsselt auf Transportebene, aber PairDrop verschlüsselt Dateiinhalte)

---

## 3. Repository-Struktur

```
CS-PairDrop/
├── .claude/
│   └── CLAUDE.md                          # AI-Anweisungen (kopiert)
├── .github/
│   ├── config/
│   │   ├── release/
│   │   │   └── semantic-release.json      # Semantic Release Config
│   │   └── docker-base-image-monitor/
│   │       └── base-images.json           # Watched upstream images (Digest-Drift)
│   ├── workflows/
│   │   ├── release.yml                    # CI/CD Pipeline + Release
│   │   ├── check-base-images.yml          # Daily Base Image Digest Monitor
│   │   ├── docker-maintenance.yml         # Auto-merge Dependabot Image PRs
│   │   ├── teams-notifications.yml        # Teams Benachrichtigungen
│   │   └── ai-issue-summary.yml           # AI Issue Summary
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── src/
│   ├── pairdrop/
│   │   └── (keine eigenen Dateien - nutzt offizielles Image)
│   ├── coturn/
│   │   ├── Dockerfile                     # Coturn mit Healthcheck
│   │   └── turnserver.conf                # TURN Konfiguration
│   ├── acme-manager/
│   │   ├── Dockerfile                     # ACME Manager Image
│   │   ├── entrypoint.sh                  # Zertifikatsverwaltung
│   │   └── www/
│   │       └── index.html                 # TURN Server Info Page
│   └── config/
│       └── rtc_config.json                # WebRTC/TURN Config für PairDrop
├── docker-compose.development.yml         # Development (Profile: turn optional)
├── docker-compose.traefik.yml             # Production mit Traefik (Profile: turn optional)
├── docker-compose.coolify.yml             # Coolify Deployment (Profile: turn optional)
├── .env.example                           # Environment Template
├── .dockerignore
├── .gitignore
├── .gitattributes
├── LICENSE
└── README.md
```

---

## 4. Service-Definitionen

### 4.1 PairDrop Service

**Base Image:** `lscr.io/linuxserver/pairdrop:latest`

**Environment Variables:**

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `PUID` | 1000 | Process User ID |
| `PGID` | 1000 | Process Group ID |
| `TZ` | Europe/Berlin | Timezone |
| `WS_FALLBACK` | false | WebSocket Fallback für VPN |
| `RATE_LIMIT` | true | Request Rate Limiting |
| `RTC_CONFIG` | /config/rtc_config.json | TURN/STUN Config Pfad |
| `DEBUG_MODE` | false | Debug Logging (nie in Prod!) |

**Ports:**
- `3000/tcp` - Web Interface & Signaling

### 4.2 Coturn Service

**Base Image:** `coturn/coturn:latest` (custom Dockerfile für Healthcheck)

**Konfiguration (`turnserver.conf`):**

```ini
# ═══════════════════════════════════════════════════════════
# COTURN TURN Server Configuration
# PairDrop Self-Hosting Stack | BAUER GROUP
# ═══════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
# Identity
# ─────────────────────────────────────────────────────────────
realm=${TURN_REALM}
server-name=${TURN_REALM}

# ─────────────────────────────────────────────────────────────
# Listener Ports
# ─────────────────────────────────────────────────────────────
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0

# ─────────────────────────────────────────────────────────────
# NAT / External IP
# ─────────────────────────────────────────────────────────────
# Bei direkter Public IP: external-ip weglassen
# Bei NAT: externe IP setzen
external-ip=${TURN_EXTERNAL_IP}

# ─────────────────────────────────────────────────────────────
# Relay Port Range (Firewall muss offen sein!)
# ─────────────────────────────────────────────────────────────
min-port=${TURN_MIN_PORT:-40000}
max-port=${TURN_MAX_PORT:-45000}

# ─────────────────────────────────────────────────────────────
# Authentication: Shared Secret (TURN REST API)
# ─────────────────────────────────────────────────────────────
use-auth-secret
static-auth-secret=${TURN_SECRET}

# ─────────────────────────────────────────────────────────────
# TLS Certificates (Let's Encrypt via ACME Manager)
# ─────────────────────────────────────────────────────────────
cert=/certs/live/${TURN_REALM}/fullchain.pem
pkey=/certs/live/${TURN_REALM}/privkey.pem

# Nur moderne TLS Versionen
no-sslv3
no-tlsv1
no-tlsv1_1

# ─────────────────────────────────────────────────────────────
# Security Hardening
# ─────────────────────────────────────────────────────────────
fingerprint

# Private Netzwerke blocken (SSRF Prevention)
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=::1

# Quotas gegen Missbrauch
user-quota=20
total-quota=2000

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
log-file=stdout
# verbose (nur für Debug!)

# ─────────────────────────────────────────────────────────────
# Security: Deaktivierte Features
# ─────────────────────────────────────────────────────────────
no-cli
no-software-attribute
no-multicast-peers
no-rfc5780
```

**Ports:**
- `3478/tcp` + `3478/udp` - STUN/TURN
- `5349/tcp` + `5349/udp` - TURNS (TLS)
- `10000-20000/udp` - Media Relay Range

### 4.3 ACME Manager Service

**Custom Image auf Basis `alpine:latest` + `lego`**

**Funktionsweise:**
1. Lauscht auf Port 80 für ACME HTTP-01 Challenge
2. Holt/erneuert Zertifikate via Let's Encrypt
3. Triggert Coturn Reload nach Erneuerung
4. Zertifikate landen in Shared Volume

**Dockerfile (`src/acme-manager/Dockerfile`):**

```dockerfile
FROM alpine:latest

ARG LEGO_VERSION=4.21.0

LABEL org.opencontainers.image.title="ACME Manager"
LABEL org.opencontainers.image.description="Let's Encrypt certificate manager for Coturn"
LABEL org.opencontainers.image.vendor="BAUER GROUP"

RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    docker-cli \
    busybox-extras

# Lego ACME Client installieren
ADD https://github.com/go-acme/lego/releases/download/v${LEGO_VERSION}/lego_v${LEGO_VERSION}_linux_amd64.tar.gz /tmp/lego.tar.gz
RUN tar -xzf /tmp/lego.tar.gz -C /usr/local/bin lego && \
    rm /tmp/lego.tar.gz && \
    chmod +x /usr/local/bin/lego

# Web Root für Info-Seite und ACME Challenge
RUN mkdir -p /var/www/.well-known/acme-challenge

COPY www/ /var/www/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/certs"]
EXPOSE 80

HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:80/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
```

**Entrypoint (`src/acme-manager/entrypoint.sh`):**

```bash
#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════
# ACME Manager Entrypoint
# PairDrop Self-Hosting Stack | BAUER GROUP
# ═══════════════════════════════════════════════════════════

DOMAIN="${ACME_DOMAIN:?ACME_DOMAIN is required}"
EMAIL="${ACME_EMAIL:?ACME_EMAIL is required}"
CERT_PATH="/certs"
COTURN_CONTAINER="${COTURN_CONTAINER_NAME:-coturn}"
RENEWAL_DAYS="${ACME_RENEWAL_DAYS:-30}"
CHECK_INTERVAL="${ACME_CHECK_INTERVAL:-12h}"
WEB_ROOT="/var/www"

echo "╔════════════════════════════════════════════════════════╗"
echo "║          ACME Manager - Let's Encrypt                  ║"
echo "╠════════════════════════════════════════════════════════╣"
echo "║ Domain:  ${DOMAIN}"
echo "║ Email:   ${EMAIL}"
echo "║ Renewal: ${RENEWAL_DAYS} days before expiry"
echo "╚════════════════════════════════════════════════════════╝"

# ─────────────────────────────────────────────────────────────
# HTTP Server starten (Info-Seite + ACME Challenge)
# ─────────────────────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting HTTP server on port 80..."

# ACME Challenge Verzeichnis erstellen
mkdir -p "${WEB_ROOT}/.well-known/acme-challenge"

# BusyBox httpd im Hintergrund starten
httpd -f -p 80 -h "${WEB_ROOT}" &
HTTP_PID=$!

echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP server started (PID: ${HTTP_PID})"

# Cleanup bei Beendigung
trap "kill ${HTTP_PID} 2>/dev/null" EXIT

# Zertifikatsverzeichnis erstellen
mkdir -p "${CERT_PATH}/live/${DOMAIN}"

# ─────────────────────────────────────────────────────────────
# Funktionen
# ─────────────────────────────────────────────────────────────

# Funktion: Zertifikat holen/erneuern
obtain_or_renew_cert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking certificate status..."

    if [ ! -f "${CERT_PATH}/.lego/certificates/${DOMAIN}.crt" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No certificate found. Obtaining new certificate..."
        lego \
            --email="${EMAIL}" \
            --domains="${DOMAIN}" \
            --http \
            --http.webroot="${WEB_ROOT}" \
            --accept-tos \
            --path="${CERT_PATH}/.lego" \
            run

        # Zertifikate in Standard-Verzeichnis kopieren
        copy_certificates
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificate exists. Checking for renewal..."
        if lego \
            --email="${EMAIL}" \
            --domains="${DOMAIN}" \
            --http \
            --http.webroot="${WEB_ROOT}" \
            --path="${CERT_PATH}/.lego" \
            renew --days "${RENEWAL_DAYS}"; then

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificate renewed successfully!"
            copy_certificates
            reload_coturn
            return 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] No renewal needed yet."
            return 1
        fi
    fi
}

# Funktion: Zertifikate in Let's Encrypt Standard-Struktur kopieren
copy_certificates() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Copying certificates to live directory..."

    cp "${CERT_PATH}/.lego/certificates/${DOMAIN}.crt" \
       "${CERT_PATH}/live/${DOMAIN}/fullchain.pem"

    cp "${CERT_PATH}/.lego/certificates/${DOMAIN}.key" \
       "${CERT_PATH}/live/${DOMAIN}/privkey.pem"

    # Berechtigungen setzen (Coturn braucht Lesezugriff)
    chmod 644 "${CERT_PATH}/live/${DOMAIN}/fullchain.pem"
    chmod 600 "${CERT_PATH}/live/${DOMAIN}/privkey.pem"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificates copied successfully!"
}

# Funktion: Coturn Reload triggern
reload_coturn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering Coturn reload..."

    if docker kill --signal=SIGUSR2 "${COTURN_CONTAINER}" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Coturn reload signal sent (SIGUSR2)"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Could not signal Coturn. Attempting restart..."
        docker restart "${COTURN_CONTAINER}" 2>/dev/null || \
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Could not restart Coturn container"
    fi
}

# ─────────────────────────────────────────────────────────────
# Main Loop
# ─────────────────────────────────────────────────────────────

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting certificate management loop..."

# Kurz warten bis HTTP Server bereit
sleep 2

# Erstes Zertifikat sofort holen
obtain_or_renew_cert || true

# Falls Zertifikat existiert aber noch nicht kopiert
if [ -f "${CERT_PATH}/.lego/certificates/${DOMAIN}.crt" ] && \
   [ ! -f "${CERT_PATH}/live/${DOMAIN}/fullchain.pem" ]; then
    copy_certificates
fi

# Endlos-Loop für Renewal Checks
while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleeping for ${CHECK_INTERVAL}..."
    sleep "${CHECK_INTERVAL}"

    obtain_or_renew_cert || true
done
```

### 4.4 RTC Config für PairDrop

**`src/config/rtc_config.json`:**

```json
{
  "iceServers": [
    {
      "urls": "stun:${TURN_REALM}:3478"
    },
    {
      "urls": [
        "turn:${TURN_REALM}:3478?transport=udp",
        "turn:${TURN_REALM}:3478?transport=tcp",
        "turns:${TURN_REALM}:5349?transport=tcp"
      ],
      "username": "pairdrop",
      "credential": "${TURN_SECRET}"
    }
  ]
}
```

> **Hinweis:** PairDrop unterstützt auch Credential-Generierung via TURN REST API. Für Einfachheit nutzen wir hier ein statisches Shared Secret.

### 4.5 TURN Server Info Page

**Zweck:** Wenn jemand den TURN-Hostname im Browser aufruft, erscheint statt einem Timeout eine informative Seite.

**`src/acme-manager/www/index.html`:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow">
    <title>TURN Server</title>
    <style>
        :root {
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent: #3b82f6;
            --accent-hover: #2563eb;
            --border: #334155;
            --success: #22c55e;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 1rem;
        }

        .container {
            max-width: 600px;
            width: 100%;
        }

        .card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 1rem;
            padding: 2.5rem;
            text-align: center;
        }

        .icon {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, var(--accent), #8b5cf6);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1.5rem;
        }

        .icon svg {
            width: 40px;
            height: 40px;
            fill: white;
        }

        h1 {
            font-size: 1.75rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }

        .subtitle {
            color: var(--text-secondary);
            font-size: 1rem;
            margin-bottom: 2rem;
        }

        .status {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(34, 197, 94, 0.1);
            border: 1px solid rgba(34, 197, 94, 0.3);
            color: var(--success);
            padding: 0.5rem 1rem;
            border-radius: 2rem;
            font-size: 0.875rem;
            font-weight: 500;
            margin-bottom: 2rem;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            background: var(--success);
            border-radius: 50%;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .info {
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            padding: 1.5rem;
            text-align: left;
            margin-bottom: 1.5rem;
        }

        .info h2 {
            font-size: 0.875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 1rem;
        }

        .info p {
            color: var(--text-secondary);
            font-size: 0.9375rem;
            line-height: 1.6;
        }

        .ports {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 0.75rem;
            margin-top: 1rem;
        }

        .port {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 0.5rem;
            padding: 0.75rem;
            text-align: center;
        }

        .port-number {
            font-family: 'SF Mono', 'Fira Code', monospace;
            font-size: 1.125rem;
            font-weight: 600;
            color: var(--accent);
        }

        .port-label {
            font-size: 0.75rem;
            color: var(--text-secondary);
            margin-top: 0.25rem;
        }

        .footer {
            color: var(--text-secondary);
            font-size: 0.8125rem;
            margin-top: 1rem;
        }

        .footer a {
            color: var(--accent);
            text-decoration: none;
        }

        .footer a:hover {
            text-decoration: underline;
        }

        @media (max-width: 480px) {
            .card {
                padding: 1.5rem;
            }
            .ports {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <div class="icon">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/>
                </svg>
            </div>

            <h1>TURN Server</h1>
            <p class="subtitle">WebRTC Relay Service</p>

            <div class="status">
                <span class="status-dot"></span>
                Operational
            </div>

            <div class="info">
                <h2>What is this?</h2>
                <p>
                    This is a <strong>TURN (Traversal Using Relays around NAT)</strong> server.
                    It helps establish peer-to-peer connections for real-time communication
                    applications like video calls, file sharing, and WebRTC services.
                </p>
                <p style="margin-top: 0.75rem;">
                    This server is part of the <strong>PairDrop</strong> infrastructure and is
                    not intended for direct browser access.
                </p>
            </div>

            <div class="info">
                <h2>Service Ports</h2>
                <div class="ports">
                    <div class="port">
                        <div class="port-number">3478</div>
                        <div class="port-label">STUN/TURN</div>
                    </div>
                    <div class="port">
                        <div class="port-number">5349</div>
                        <div class="port-label">TURNS (TLS)</div>
                    </div>
                </div>
            </div>

            <p class="footer">
                Powered by <a href="https://github.com/coturn/coturn" target="_blank" rel="noopener">Coturn</a>
                &middot; Operated by BAUER GROUP
            </p>
        </div>
    </div>
</body>
</html>
```

---

## 5. Docker Compose Definitionen

### 5.1 Development (`docker-compose.development.yml`)

**Use Case:** Lokale Entwicklung ohne TLS, direkter Port-Zugriff
**Profile:** `--profile turn` aktiviert Coturn TURN Server

```yaml
name: pairdrop-dev

services:
  # ═══════════════════════════════════════════════════════════
  # PairDrop - File Sharing Web App
  # ═══════════════════════════════════════════════════════════
  pairdrop:
    image: lscr.io/linuxserver/pairdrop:latest
    container_name: ${STACK_NAME:-pairdrop}_pairdrop
    restart: unless-stopped
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TIME_ZONE:-Europe/Berlin}
      - WS_FALLBACK=${WS_FALLBACK:-true}
      - RATE_LIMIT=${RATE_LIMIT:-false}
      - RTC_CONFIG=/config/rtc_config.json
      - DEBUG_MODE=${DEBUG_MODE:-false}
    volumes:
      - ./src/config/rtc_config.json:/config/rtc_config.json:ro
    ports:
      - "${PAIRDROP_PORT:-3000}:3000/tcp"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      start_period: 15s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  # ═══════════════════════════════════════════════════════════
  # Coturn - TURN/STUN Server (ohne TLS für Development)
  # Aktiviert via: --profile turn
  # ═══════════════════════════════════════════════════════════
  coturn:
    profiles: [turn]
    image: coturn/coturn:latest
    container_name: ${STACK_NAME:-pairdrop}_coturn
    restart: unless-stopped
    command: >
      -n
      --realm=${TURN_REALM:-localhost}
      --listening-port=3478
      --listening-ip=0.0.0.0
      --min-port=${TURN_MIN_PORT:-40000}
      --max-port=${TURN_MAX_PORT:-40100}
      --use-auth-secret
      --static-auth-secret=${TURN_SECRET:-development-secret-change-me}
      --fingerprint
      --log-file=stdout
      --no-cli
      --no-software-attribute
      --user-quota=20
      --total-quota=500
    ports:
      - "${TURN_PORT:-3478}:3478/tcp"
      - "${TURN_PORT:-3478}:3478/udp"
      - "${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-40100}:${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-40100}/udp"
    healthcheck:
      test: ["CMD", "turnadmin", "-l", "-N", "localhost"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### 5.2 Production mit Traefik (`docker-compose.traefik.yml`)

**Use Case:** Production mit HTTPS via Traefik
**Profile:** `--profile turn` aktiviert Coturn TURN Server mit eigenem TLS

```yaml
name: pairdrop-prod

services:
  # ═══════════════════════════════════════════════════════════
  # PairDrop - File Sharing Web App
  # ═══════════════════════════════════════════════════════════
  pairdrop:
    image: lscr.io/linuxserver/pairdrop:latest
    container_name: ${STACK_NAME}_pairdrop
    restart: unless-stopped
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TIME_ZONE:-Europe/Berlin}
      - WS_FALLBACK=${WS_FALLBACK:-true}
      - RATE_LIMIT=${RATE_LIMIT:-true}
      - RTC_CONFIG=/config/rtc_config.json
      - DEBUG_MODE=false
    volumes:
      - ./src/config/rtc_config.json:/config/rtc_config.json:ro
    expose:
      - "3000"
    networks:
      - internal
      - proxy
    labels:
      # Traefik Enable
      - traefik.enable=true
      - traefik.docker.network=${PROXY_NETWORK:-proxy}

      # HTTP Router (Redirect to HTTPS)
      - traefik.http.routers.${STACK_NAME}-pairdrop-http.rule=Host(`${PAIRDROP_HOSTNAME}`)
      - traefik.http.routers.${STACK_NAME}-pairdrop-http.entrypoints=http
      - traefik.http.routers.${STACK_NAME}-pairdrop-http.middlewares=https-redirect@file

      # HTTPS Router
      - traefik.http.routers.${STACK_NAME}-pairdrop-https.rule=Host(`${PAIRDROP_HOSTNAME}`)
      - traefik.http.routers.${STACK_NAME}-pairdrop-https.entrypoints=https
      - traefik.http.routers.${STACK_NAME}-pairdrop-https.tls=true
      - traefik.http.routers.${STACK_NAME}-pairdrop-https.tls.certresolver=letsencrypt

      # Service
      - traefik.http.services.${STACK_NAME}-pairdrop.loadbalancer.server.port=3000

      # WebSocket Support
      - traefik.http.middlewares.${STACK_NAME}-ws.headers.customrequestheaders.Connection=Upgrade
      - traefik.http.middlewares.${STACK_NAME}-ws.headers.customrequestheaders.Upgrade=websocket
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      start_period: 15s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

  # ═══════════════════════════════════════════════════════════
  # ACME Manager - Let's Encrypt für Coturn
  # Aktiviert via: --profile turn
  # ═══════════════════════════════════════════════════════════
  acme-manager:
    profiles: [turn]
    build:
      context: ./src/acme-manager
      dockerfile: Dockerfile
    container_name: ${STACK_NAME}_acme
    restart: unless-stopped
    environment:
      - ACME_DOMAIN=${TURN_HOSTNAME}
      - ACME_EMAIL=${ACME_EMAIL}
      - COTURN_CONTAINER_NAME=${STACK_NAME}_coturn
      - ACME_RENEWAL_DAYS=30
      - ACME_CHECK_INTERVAL=12h
    volumes:
      - certs:/certs
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - proxy
    labels:
      # Traefik: Nur ACME Challenge durchleiten (Port 80)
      - traefik.enable=true
      - traefik.docker.network=${PROXY_NETWORK:-proxy}
      # ACME Challenge + TURN Info Page
      - traefik.http.routers.${STACK_NAME}-acme.rule=Host(`${TURN_HOSTNAME}`)
      - traefik.http.routers.${STACK_NAME}-acme.entrypoints=http
      - traefik.http.services.${STACK_NAME}-acme.loadbalancer.server.port=80
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  # ═══════════════════════════════════════════════════════════
  # Coturn - TURN/STUN Server mit eigenem TLS
  # Aktiviert via: --profile turn
  # ═══════════════════════════════════════════════════════════
  coturn:
    profiles: [turn]
    build:
      context: ./src/coturn
      dockerfile: Dockerfile
    container_name: ${STACK_NAME}_coturn
    restart: unless-stopped
    environment:
      - TURN_REALM=${TURN_HOSTNAME}
      - TURN_SECRET=${TURN_SECRET}
      - TURN_EXTERNAL_IP=${TURN_EXTERNAL_IP}
    volumes:
      - certs:/certs:ro
      - ./src/coturn/turnserver.conf:/etc/coturn/turnserver.conf:ro
    ports:
      # STUN/TURN (nicht über Traefik!)
      - "3478:3478/tcp"
      - "3478:3478/udp"
      # TURNS (TLS - von Coturn selbst terminiert!)
      - "5349:5349/tcp"
      - "5349:5349/udp"
      # Media Relay Range
      - "${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-45000}:${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-45000}/udp"
    networks:
      - internal
    healthcheck:
      test: ["CMD", "turnadmin", "-l", "-N", "localhost"]
      interval: 30s
      timeout: 10s
      start_period: 30s
      retries: 3
    depends_on:
      acme-manager:
        condition: service_healthy
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

volumes:
  certs:
    name: ${STACK_NAME}_certs

networks:
  internal:
    name: ${STACK_NAME}_internal
  proxy:
    name: ${PROXY_NETWORK:-proxy}
    external: true
```

### 5.3 Coolify Deployment (`docker-compose.coolify.yml`)

**Use Case:** Self-hosted PaaS via Coolify
**Profile:** `--profile turn` aktiviert Coturn TURN Server mit eigenem TLS

```yaml
name: pairdrop-coolify

services:
  # ═══════════════════════════════════════════════════════════
  # PairDrop - File Sharing Web App
  # ═══════════════════════════════════════════════════════════
  pairdrop:
    image: lscr.io/linuxserver/pairdrop:latest
    container_name: pairdrop_server
    restart: unless-stopped
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TIME_ZONE:-Europe/Berlin}
      - WS_FALLBACK=${WS_FALLBACK:-true}
      - RATE_LIMIT=${RATE_LIMIT:-true}
      - RTC_CONFIG=/config/rtc_config.json
      - DEBUG_MODE=false
    volumes:
      - ./src/config/rtc_config.json:/config/rtc_config.json:ro
    ports:
      - "3000:3000/tcp"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      start_period: 15s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

  # ═══════════════════════════════════════════════════════════
  # ACME Manager - Let's Encrypt für Coturn
  # Aktiviert via: --profile turn
  # ═══════════════════════════════════════════════════════════
  acme-manager:
    profiles: [turn]
    build:
      context: ./src/acme-manager
      dockerfile: Dockerfile
    container_name: pairdrop_acme
    restart: unless-stopped
    environment:
      - ACME_DOMAIN=${TURN_HOSTNAME}
      - ACME_EMAIL=${ACME_EMAIL}
      - COTURN_CONTAINER_NAME=pairdrop_coturn
      - ACME_RENEWAL_DAYS=30
      - ACME_CHECK_INTERVAL=12h
    volumes:
      - certs:/certs
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "80:80/tcp"  # Direkt exponiert für ACME Challenge
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  # ═══════════════════════════════════════════════════════════
  # Coturn - TURN/STUN Server mit eigenem TLS
  # Aktiviert via: --profile turn
  # ═══════════════════════════════════════════════════════════
  coturn:
    profiles: [turn]
    build:
      context: ./src/coturn
      dockerfile: Dockerfile
    container_name: pairdrop_coturn
    restart: unless-stopped
    environment:
      - TURN_REALM=${TURN_HOSTNAME}
      - TURN_SECRET=${TURN_SECRET}
      - TURN_EXTERNAL_IP=${TURN_EXTERNAL_IP}
    volumes:
      - certs:/certs:ro
      - ./src/coturn/turnserver.conf:/etc/coturn/turnserver.conf:ro
    ports:
      - "3478:3478/tcp"
      - "3478:3478/udp"
      - "5349:5349/tcp"
      - "5349:5349/udp"
      - "${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-45000}:${TURN_MIN_PORT:-40000}-${TURN_MAX_PORT:-45000}/udp"
    healthcheck:
      test: ["CMD", "turnadmin", "-l", "-N", "localhost"]
      interval: 30s
      timeout: 10s
      start_period: 30s
      retries: 3
    depends_on:
      acme-manager:
        condition: service_healthy
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

volumes:
  certs:
    name: pairdrop_certs
```

---

## 6. Environment Konfiguration

### 6.1 `.env.example`

```bash
# ═══════════════════════════════════════════════════════════
# PairDrop Self-Hosting Stack - Environment Configuration
# BAUER GROUP | CS-PairDrop
# ═══════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
# Stack Identification
# ─────────────────────────────────────────────────────────────
STACK_NAME=pairdrop_xxx_app_bauer-group_com

# ─────────────────────────────────────────────────────────────
# Common Settings
# ─────────────────────────────────────────────────────────────
TIME_ZONE=Europe/Berlin
PUID=1000
PGID=1000

# ─────────────────────────────────────────────────────────────
# PairDrop Settings
# ─────────────────────────────────────────────────────────────
PAIRDROP_HOSTNAME=drop.app.bauer-group.com
WS_FALLBACK=true
RATE_LIMIT=true
DEBUG_MODE=false

# Development only:
PAIRDROP_PORT=3000

# ─────────────────────────────────────────────────────────────
# TURN Server Settings
# ─────────────────────────────────────────────────────────────
TURN_HOSTNAME=turn.app.bauer-group.com
TURN_SECRET=CHANGE_ME_TO_A_LONG_RANDOM_SECRET_MIN_32_CHARS
TURN_EXTERNAL_IP=

# Port Range for Media Relay (default: 40000-45000)
TURN_MIN_PORT=40000
TURN_MAX_PORT=45000

# Development only:
TURN_PORT=3478

# ─────────────────────────────────────────────────────────────
# ACME / Let's Encrypt
# ─────────────────────────────────────────────────────────────
ACME_EMAIL=admin@bauer-group.com

# ─────────────────────────────────────────────────────────────
# Network (Production)
# ─────────────────────────────────────────────────────────────
PROXY_NETWORK=proxy
```

---

## 7. CI/CD Pipeline

### 7.1 Release Workflow (`.github/workflows/release.yml`)

Nutzt die bestehende Struktur aus dem Dashboard-Template:

- **Docker Compose Validation** für alle 3 Compose-Dateien
- **Dockerfile Linting** via Hadolint
- **Shell Script Validation** via ShellCheck
- **Semantic Release** für automatische Versionierung

### 7.2 Zu validierende Dateien

| Datei | Validierung |
|-------|-------------|
| `docker-compose.development.yml` | Docker Compose Config |
| `docker-compose.traefik.yml` | Docker Compose Config |
| `docker-compose.coolify.yml` | Docker Compose Config |
| `src/acme-manager/Dockerfile` | Hadolint |
| `src/coturn/Dockerfile` | Hadolint |
| `src/acme-manager/entrypoint.sh` | ShellCheck |

### 7.3 Automatische Image-Wartung

Zwei sich ergänzende Mechanismen sorgen dafür, dass dieses Repo automatisch auf
Änderungen abhängiger Container-Images reagiert.

**Dependabot (Tag-Bumps)** — `.github/dependabot.yml`

Öffnet wöchentlich (So 06:30 UTC) PRs, wenn ein referenzierter Image-Tag auf eine
neue Major/Minor-Variante springt (z. B. `alpine:3.20` → `alpine:3.21`). Watched
ecosystems:

| Ecosystem | Verzeichnis | Zweck |
|-----------|-------------|-------|
| `github-actions` | `/` | Action-Versionen in Workflows |
| `docker-compose` | `/` | Upstream-Images in `docker-compose*.yml` |
| `docker` | `/src/acme-manager` | `FROM alpine:…` |
| `docker` | `/src/coturn` | `FROM coturn/coturn:…` |
| `docker` | `/src/config` | `FROM alpine:…` |

**Base-Image-Monitor (Digest-Drift)** — `.github/workflows/check-base-images.yml`

Daily-Cron (10:00 UTC) prüft Digest-Drift auf den unten gelisteten Floating-Tags.
Bei einer Änderung wird ein Commit auf `main` erzeugt und anschließend
`release.yml` mit `force-release=true` getriggert, sodass ein neues Release
geschnitten wird. Konfiguration:
`.github/config/docker-base-image-monitor/base-images.json`

| Name | Image | Tag | Verwendung |
|------|-------|-----|------------|
| `pairdrop` | `lscr.io/linuxserver/pairdrop` | `latest` | Alle `docker-compose*.yml` |
| `coturn` | `coturn/coturn` | `latest` | `src/coturn/Dockerfile` + Development-Compose |
| `alpine` | `alpine` | `latest` | `src/acme-manager/Dockerfile` + `src/config/Dockerfile` |

**Auto-Merge** — `.github/workflows/docker-maintenance.yml`

Dependabot-PRs auf `src/**/Dockerfile` oder `docker-compose*.yml` werden nach
erfolgreicher Validierung automatisch approved und gemerged (Squash). Nach dem
Merge feuert `release.yml` und cuttet ein neues Release.

---

## 8. Firewall / Port Requirements

### 8.1 Development

| Port | Protokoll | Service | Beschreibung |
|------|-----------|---------|--------------|
| 3000 | TCP | PairDrop | Web Interface |
| 3478 | TCP/UDP | Coturn | STUN/TURN |
| 40000-40100 | UDP | Coturn | Media Relay (reduziert für Dev) |

### 8.2 Production

| Port | Protokoll | Service | Beschreibung |
|------|-----------|---------|--------------|
| 80 | TCP | Traefik/ACME | HTTP + ACME Challenge + TURN Info |
| 443 | TCP | Traefik | HTTPS (PairDrop) |
| 3478 | TCP/UDP | Coturn | STUN/TURN |
| 5349 | TCP/UDP | Coturn | TURNS (TLS) |
| 40000-45000 | UDP | Coturn | Media Relay (konfigurierbar) |

---

## 9. Security Considerations

### 9.1 Docker Socket Mount

**Risiko:** ACME Manager benötigt Docker Socket für Coturn Reload

**Mitigationen:**
- Read-only Mount (`:ro`)
- Dedizierter Container mit minimalem Image
- Nur `kill` und `restart` Befehle verwendet
- Alternativ: Coolify API / Webhook-basierter Reload

### 9.2 TURN Secret

**Empfehlungen:**
- Mindestens 32 Zeichen, zufällig generiert
- Niemals in Git committen
- Via Secret Manager oder `.env` (gitignored)

**Generierung:**
```bash
openssl rand -base64 32
```

### 9.3 Private Network Blocking

Coturn blockt per Default:
- `10.0.0.0/8` (Private Class A)
- `172.16.0.0/12` (Private Class B)
- `192.168.0.0/16` (Private Class C)
- `127.0.0.0/8` (Loopback)
- `169.254.0.0/16` (Link-Local)

---

## 10. Deployment Checkliste

### 10.1 Pre-Deployment

- [ ] DNS Records erstellt (PairDrop + TURN Hostname)
- [ ] Firewall Ports geöffnet (siehe Sektion 8)
- [ ] `.env` aus `.env.example` erstellt
- [ ] `TURN_SECRET` generiert und eingetragen
- [ ] `TURN_EXTERNAL_IP` gesetzt (falls hinter NAT)
- [ ] `ACME_EMAIL` eingetragen

### 10.2 Deployment

```bash
# Development
docker compose -f docker-compose.development.yml up -d

# Production (Traefik)
docker compose -f docker-compose.traefik.yml up -d

# Coolify
# Via Coolify UI deployen
```

### 10.3 Post-Deployment Verification

- [ ] PairDrop Web Interface erreichbar
- [ ] HTTPS Zertifikat gültig (PairDrop)
- [ ] TURN Server erreichbar (Port 3478)
- [ ] TURNS TLS funktioniert (Port 5349)
- [ ] File Transfer zwischen zwei Geräten erfolgreich
- [ ] Transfer über verschiedene Netzwerke (TURN) erfolgreich

---

## 11. Dateien zu erstellen

| # | Datei | Beschreibung |
|---|-------|--------------|
| 1 | `src/acme-manager/Dockerfile` | ACME Manager Image |
| 2 | `src/acme-manager/entrypoint.sh` | ACME Entrypoint Script |
| 3 | `src/acme-manager/www/index.html` | TURN Server Info Page |
| 4 | `src/coturn/Dockerfile` | Coturn Image mit Healthcheck |
| 5 | `src/coturn/turnserver.conf` | TURN Server Konfiguration |
| 6 | `src/config/rtc_config.json` | WebRTC/TURN Config |
| 7 | `docker-compose.development.yml` | Development (Profile: turn) |
| 8 | `docker-compose.traefik.yml` | Production mit Traefik (Profile: turn) |
| 9 | `docker-compose.coolify.yml` | Coolify (Profile: turn) |
| 10 | `.env.example` | Environment Template |
| 11 | `.gitignore` | Git Ignores |
| 12 | `.dockerignore` | Docker Ignores |
| 13 | `README.md` | Dokumentation |
| 14 | `.github/workflows/release.yml` | CI/CD Pipeline |
| 15 | `.github/config/release/semantic-release.json` | Release Config |

---

## 12. Entschiedene Konfiguration

### 12.1 Festgelegte Werte

| Parameter | Wert | Notiz |
|-----------|------|-------|
| **PairDrop Hostname** | `drop.app.bauer-group.com` | Konfigurierbar via `.env` |
| **TURN Hostname** | `turn.app.bauer-group.com` | Konfigurierbar via `.env` |
| **TURN Port Range** | `40000-45000` | Konfigurierbar (TURN_MIN_PORT, TURN_MAX_PORT) |
| **WS_FALLBACK** | `true` | Aktiviert für VPN-User |

### 12.2 Optionale Erweiterungen (Zukunft)

- [ ] DNS-01 ACME Challenge (kein Port 80 nötig)
- [ ] Multi-Domain Support (mehrere TURN Domains)
- [ ] HA Setup (2+ TURN Nodes)
- [ ] Prometheus Metrics Export
- [ ] Grafana Dashboard

---

## 13. Freigabe

**Konzept erstellt:** 2026-01-22
**Version:** 1.0.0

### Zur Umsetzung freigegeben?

- [ ] Ja, Konzept ist vollständig und kann umgesetzt werden
- [ ] Nein, folgende Punkte müssen geklärt werden: ___

---

*BAUER GROUP | Building Better Software Together*
