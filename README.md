# Valheim Docker Server

Dockerized Valheim dedicated server with BepInEx mod support, automated backups, and remote management.

## Features

- **Debian Bookworm** slim base image
- **BepInEx** mod framework support
- **Automated backups** with rotation
- **Scheduled restarts** with idle detection
- **Remote syslog** support via BusyBox
- **Supervisor HTTP** web interface
- **Graceful shutdown** for world save protection

## Quick Start

```bash
# Build the image
docker-compose build

# Start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop gracefully
docker-compose down
```

## Environment Variables

### Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | Valheim Server | Display name in server browser |
| `SERVER_PORT` | 2456 | Game port (UDP) |
| `WORLD_NAME` | Dedicated | World file name |
| `SERVER_PASS` | (empty) | Password (min 5 chars) |
| `SERVER_PUBLIC` | 1 | List in server browser |
| `CROSSPLAY` | false | Enable crossplay |

### Backup Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUPS` | true | Enable backups |
| `BACKUPS_CRON` | 0 * * * * | Cron schedule |
| `BACKUPS_MAX_AGE` | 3 | Days to keep |
| `BACKUPS_MAX_COUNT` | 0 | Max backups (0=unlimited) |
| `BACKUPS_IF_IDLE` | true | Only backup when idle |
| `BACKUPS_ZIP` | true | Compress backups |

### Other Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | UTC | Timezone |
| `RESTART_CRON` | (empty) | Restart schedule |
| `RESTART_IF_IDLE` | true | Only restart when idle |
| `BEPINEX` | false | Enable BepInEx |
| `SUPERVISOR_HTTP` | false | Enable web UI |

## Volumes

| Path | Purpose |
|------|---------|
| `/config` | World saves, server config |
| `/bepinex` | BepInEx plugins/config |
| `/backups` | Backup archives |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2456 | UDP | Game port |
| 2457 | UDP | Query port |
| 9001 | TCP | Supervisor HTTP |

## BepInEx Setup

1. Download [BepInExPack Valheim](https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/)
2. Extract to a local `bepinex` folder
3. Mount the volume and enable:

```yaml
environment:
  - BEPINEX=true
volumes:
  - ./bepinex:/bepinex
```

## Management Commands

```bash
# View server status
docker exec valheim-server /opt/valheim/scripts/valheim-status

# Manual backup
docker exec valheim-server /opt/valheim/scripts/valheim-backup

# Manual update
docker exec valheim-server /opt/valheim/scripts/valheim-updater

# Supervisor control
docker exec valheim-server supervisorctl status
docker exec valheim-server supervisorctl restart valheim-server
```

## License

MIT
