# PairDrop Self-Hosting Stack

Professional self-hosting stack for [PairDrop](https://github.com/schlagmichdansen/pairdrop) with optional Coturn TURN Server.

## Overview

This project deploys PairDrop, a local file sharing solution inspired by Apple's AirDrop, with optional NAT traversal support via a self-hosted Coturn TURN server.

**Features:**
- Local file sharing without internet dependency
- WebRTC-based peer-to-peer transfers
- Optional TURN server for cross-network transfers
- Automatic Let's Encrypt TLS certificates
- Three deployment modes: Development, Traefik, Coolify

## Quick Start

### Prerequisites

- Docker & Docker Compose
- For production: Traefik reverse proxy with Let's Encrypt
- For TURN: Public IP and open firewall ports

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/bauer-group/CS-PairDrop.git
   cd CS-PairDrop
   ```

2. Create environment file:
   ```bash
   cp .env.example .env
   ```

3. Edit `.env` and adjust values:
   ```bash
   # Required
   STACK_NAME=pairdrop_yoursite
   PAIRDROP_HOSTNAME=drop.yourdomain.com

   # Only if using TURN (--profile turn)
   TURN_HOSTNAME=turn.yourdomain.com
   TURN_SECRET=$(openssl rand -base64 32)
   ACME_EMAIL=admin@yourdomain.com
   ```

4. Start the container:
   ```bash
   # Without TURN (WebSocket Fallback)
   docker compose -f docker-compose.traefik.yml up -d

   # With TURN (NAT Traversal)
   docker compose -f docker-compose.traefik.yml --profile turn up -d
   ```

5. Access PairDrop:
   - Development: http://localhost:3000
   - Production: https://drop.yourdomain.com

## Deployment Options

### Without TURN Server (Default)

Uses WebSocket fallback for file transfers. Best for:
- All devices in the same local network
- Simple setups without NAT traversal needs
- Using an external TURN server

```bash
docker compose -f docker-compose.development.yml up -d
docker compose -f docker-compose.traefik.yml up -d
docker compose -f docker-compose.coolify.yml up -d
```

### With TURN Server (`--profile turn`)

Self-hosted TURN server with automatic Let's Encrypt certificates. Best for:
- Devices across different networks
- Enterprise deployments
- Full control over NAT traversal

```bash
docker compose -f docker-compose.development.yml --profile turn up -d
docker compose -f docker-compose.traefik.yml --profile turn up -d
docker compose -f docker-compose.coolify.yml --profile turn up -d
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STACK_NAME` | `pairdrop_xxx_app_bauer-group_com` | Container naming prefix |
| `TIME_ZONE` | `Europe/Berlin` | Container timezone |
| `PAIRDROP_HOSTNAME` | `drop.app.bauer-group.com` | PairDrop hostname |
| `WS_FALLBACK` | `true` | Enable WebSocket fallback |
| `RATE_LIMIT` | `true` | Enable rate limiting |
| `TURN_HOSTNAME` | `turn.app.bauer-group.com` | TURN server hostname |
| `TURN_SECRET` | - | TURN authentication secret (min 32 chars) |
| `TURN_MIN_PORT` | `40000` | Media relay port range start |
| `TURN_MAX_PORT` | `45000` | Media relay port range end |
| `ACME_EMAIL` | - | Let's Encrypt notification email |
| `PROXY_NETWORK` | `proxy` | Traefik network name |

### Firewall Ports (with TURN)

| Port | Protocol | Service |
|------|----------|---------|
| 80 | TCP | ACME Challenge + TURN Info Page |
| 443 | TCP | HTTPS (PairDrop via Traefik) |
| 3478 | TCP/UDP | STUN/TURN |
| 5349 | TCP/UDP | TURNS (TLS) |
| 40000-45000 | UDP | Media Relay |

## Architecture

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
          │                └─────┬─────┘              │  :40000-  │
          │                      │                    │   45000   │
          ▼                      ▼                    └─────┬─────┘
    ┌───────────┐          ┌───────────┐                    │
    │ PairDrop  │          │  Shared   │◄───────────────────┘
    │  :3000    │          │  Certs    │
    └───────────┘          │  Volume   │
                           └───────────┘
```

## Security

### TURN Secret

Generate a secure TURN secret:
```bash
openssl rand -base64 32
```

### Docker Socket

The ACME Manager requires read-only access to the Docker socket to reload Coturn certificates. This is mitigated by:
- Read-only mount (`:ro`)
- Minimal Alpine-based image
- Only `kill` and `restart` commands used

### Private Network Blocking

Coturn blocks relay to private networks (SSRF prevention):
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`
- `127.0.0.0/8`
- `169.254.0.0/16`

## Troubleshooting

### TURN Server not working

1. Check firewall ports (3478, 5349, 40000-45000)
2. Verify TURN_EXTERNAL_IP is set (if behind NAT)
3. Check certificate status: `docker logs pairdrop_acme`

### WebSocket Fallback

If transfers fail, ensure `WS_FALLBACK=true` in `.env`. This routes traffic through the server instead of P2P.

### Certificate Issues

View ACME Manager logs:
```bash
docker logs pairdrop_acme -f
```

## Documentation

- [PairDrop Documentation](https://github.com/schlagmichdansen/pairdrop)
- [LinuxServer PairDrop Image](https://docs.linuxserver.io/images/docker-pairdrop/)
- [Coturn Documentation](https://github.com/coturn/coturn)
- [Lego ACME Client](https://go-acme.github.io/lego/)

## License

MIT License - See [LICENSE](LICENSE) for details.

---

**BAUER GROUP** | Building Better Software Together
