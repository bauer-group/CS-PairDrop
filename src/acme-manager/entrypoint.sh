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
