#!/bin/bash
# Valheim Docker Entrypoint
# Starts supervisord which manages all processes

set -e

log() {
    echo "[entrypoint] $*"
}

log "=== Valheim Docker Container Starting ==="
log "Server: ${SERVER_NAME:-Valheim Server}"
log "World: ${WORLD_NAME:-Dedicated}"
log "Port: ${SERVER_PORT:-2456}"
log "Public: ${SERVER_PUBLIC:-1}"
log "Crossplay: ${CROSSPLAY:-false}"
log "BepInEx: ${BEPINEX:-false}"
log "Backups: ${BACKUPS:-true}"

# Set timezone
if [[ -n "$TZ" && -f "/usr/share/zoneinfo/$TZ" ]]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    log "Timezone: $TZ"
fi

# Generate supervisord configuration
/opt/valheim/scripts/generate-supervisord-conf

# Start supervisord - only tag lines that don't already have a tag
log "Starting supervisord..."
exec > >(exec sed -u '/^\[/!s/^/[supervisord] /') 2>&1
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
