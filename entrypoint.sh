#!/bin/bash
# Valheim Docker Entrypoint
# Starts syslogd (if configured) then supervisord
# All other initialization is done by valheim-init via supervisord

set -e

# Logging function for entrypoint (before common.sh is available)
log_entry() {
    local tag="valheim-entrypoint"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tag] $*"
    # Send to syslog if /dev/log exists
    if [[ -S /dev/log ]]; then
        /usr/local/bin/logger -t "$tag" -p local0.info "$*" 2>/dev/null || true
    fi
}

log_entry "=== Valheim Docker Container Starting ==="
log_entry "Version: 1.0.0"

# Set timezone
if [[ -n "$TZ" && -f "/usr/share/zoneinfo/$TZ" ]]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    log_entry "Timezone set to: $TZ"
fi

# Start syslogd FIRST (before supervisord) to capture all logs
if [[ -n "$SYSLOG_REMOTE_HOST" ]]; then
    log_entry "Starting syslogd (remote: $SYSLOG_REMOTE_HOST:$SYSLOG_REMOTE_PORT)..."

    syslog_args="-R ${SYSLOG_REMOTE_HOST}:${SYSLOG_REMOTE_PORT}"
    if [[ "$SYSLOG_REMOTE_AND_LOCAL" == "true" ]]; then
        syslog_args+=" -L"
    fi

    # Start syslogd daemonized
    /usr/local/bin/syslogd $syslog_args

    # Wait for /dev/log socket
    timeout=10
    elapsed=0
    while [[ ! -S /dev/log && $elapsed -lt $timeout ]]; do
        sleep 0.5
        ((elapsed++)) || true
    done

    if [[ -S /dev/log ]]; then
        log_entry "Syslogd started, /dev/log ready"
    else
        log_entry "WARN: Syslogd may not have started correctly"
    fi
fi

# Generate supervisord configuration
/opt/valheim/scripts/generate-supervisord-conf
if [[ "$SUPERVISOR_HTTP" == "true" ]]; then
    log_entry "Supervisor HTTP enabled on port $SUPERVISOR_HTTP_PORT"
fi
log_entry "Supervisord configuration generated"

# Start supervisord
log_entry "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
