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

# Generate supervisord configuration directly (avoid sed with multiline)
generate_supervisord_conf() {
    local output="/etc/supervisor/supervisord.conf"
    mkdir -p /etc/supervisor

    cat > "$output" << 'SUPERVISOR_BASE'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
pidfile=/var/run/supervisord.pid

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

SUPERVISOR_BASE

    # Add HTTP server section if enabled
    if [[ "$SUPERVISOR_HTTP" == "true" ]]; then
        log_entry "Enabling supervisor HTTP on port $SUPERVISOR_HTTP_PORT"
        cat >> "$output" << SUPERVISOR_HTTP
[inet_http_server]
port=0.0.0.0:${SUPERVISOR_HTTP_PORT}
username=${SUPERVISOR_HTTP_USER}
password=${SUPERVISOR_HTTP_PASS}

SUPERVISOR_HTTP
    fi

    # Build environment string with all needed variables
    local env_vars="SYSLOG_REMOTE_HOST=\"${SYSLOG_REMOTE_HOST:-}\""
    env_vars+=",SYSLOG_REMOTE_PORT=\"${SYSLOG_REMOTE_PORT:-514}\""
    env_vars+=",SERVER_NAME=\"${SERVER_NAME}\""
    env_vars+=",SERVER_PORT=\"${SERVER_PORT}\""
    env_vars+=",WORLD_NAME=\"${WORLD_NAME}\""
    env_vars+=",SERVER_PASS=\"${SERVER_PASS}\""
    env_vars+=",SERVER_PUBLIC=\"${SERVER_PUBLIC}\""
    env_vars+=",CROSSPLAY=\"${CROSSPLAY}\""
    env_vars+=",BEPINEX=\"${BEPINEX}\""
    env_vars+=",BEPINEX_VERSION=\"${BEPINEX_VERSION:-}\""
    env_vars+=",BACKUPS=\"${BACKUPS}\""
    env_vars+=",BACKUPS_CRON=\"${BACKUPS_CRON}\""
    env_vars+=",BACKUPS_MAX_AGE=\"${BACKUPS_MAX_AGE}\""
    env_vars+=",BACKUPS_MAX_COUNT=\"${BACKUPS_MAX_COUNT}\""
    env_vars+=",BACKUPS_IF_IDLE=\"${BACKUPS_IF_IDLE}\""
    env_vars+=",BACKUPS_IDLE_GRACE_PERIOD=\"${BACKUPS_IDLE_GRACE_PERIOD}\""
    env_vars+=",BACKUPS_ZIP=\"${BACKUPS_ZIP}\""
    env_vars+=",RESTART_CRON=\"${RESTART_CRON}\""
    env_vars+=",RESTART_IF_IDLE=\"${RESTART_IF_IDLE}\""

    # Add program sections with environment
    cat >> "$output" << SUPERVISOR_PROGRAMS
[program:valheim-init]
command=/opt/valheim/scripts/valheim-init
user=root
priority=1
autostart=true
autorestart=false
startsecs=0
exitcodes=0
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
environment=${env_vars}

[program:valheim-server]
command=/bin/bash -c 'exec /opt/valheim/scripts/valheim-server > >(exec /opt/valheim/scripts/container-log-filter) 2>&1'
user=root
directory=/opt/valheim/server
priority=10
autostart=false
autorestart=true
startsecs=10
startretries=3
stopwaitsecs=60
stopsignal=INT
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
environment=HOME="/root",USER="root",${env_vars}

[program:cron]
command=/usr/sbin/cron -f
user=root
priority=10
autostart=true
autorestart=true
startsecs=1
stopwaitsecs=5
stopsignal=TERM
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0

[program:valheim-updater]
command=/opt/valheim/scripts/valheim-updater
user=root
priority=20
autostart=false
autorestart=false
startsecs=0
exitcodes=0,1
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
environment=${env_vars}

[program:valheim-updater-bepinex]
command=/opt/valheim/scripts/valheim-bepinex-updater
user=root
priority=21
autostart=false
autorestart=false
startsecs=0
exitcodes=0,1
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
environment=${env_vars}
SUPERVISOR_PROGRAMS

    log_entry "Supervisord configuration generated"
}

generate_supervisord_conf

log_entry "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
