#!/bin/bash
# Common functions and variables for Valheim scripts

export VALHEIM_DIR="/opt/valheim/server"
export CONFIG_DIR="/saves"
export BACKUP_DIR="/backups"
export STEAMCMD="/opt/steamcmd/steamcmd.sh"
export VALHEIM_APP_ID=896660
export VALHEIM_PID_FILE="/var/run/valheim.pid"

# Script name for logging - each script should set this before sourcing or after
# Default to the calling script's basename
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "${BASH_SOURCE[1]:-${0}}" 2>/dev/null || echo 'valheim')}"

# Logging functions with script identification
log() {
    local tag="valheim-${SCRIPT_NAME}"
    local msg="[$tag] $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg"
    # Always try to send to syslog if /dev/log exists
    if [[ -S /dev/log ]]; then
        /usr/local/bin/logger -t "$tag" -p local0.info "$*" 2>/dev/null || true
    fi
}

log_error() {
    local tag="valheim-${SCRIPT_NAME}"
    local msg="[$tag] ERROR: $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >&2
    if [[ -S /dev/log ]]; then
        /usr/local/bin/logger -t "$tag" -p local0.err "ERROR: $*" 2>/dev/null || true
    fi
}

log_warn() {
    local tag="valheim-${SCRIPT_NAME}"
    local msg="[$tag] WARN: $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg"
    if [[ -S /dev/log ]]; then
        /usr/local/bin/logger -t "$tag" -p local0.warning "WARN: $*" 2>/dev/null || true
    fi
}

# Get server PID
get_server_pid() {
    pgrep -f "valheim_server.x86_64" 2>/dev/null || echo ""
}

# Check if server is running
is_server_running() {
    local pid
    pid=$(get_server_pid)
    [[ -n "$pid" ]]
}

# Get player count by parsing server log
# Returns 0 if unable to determine
get_player_count() {
    local log_file="$CONFIG_DIR/server.log"
    local count=0

    # Try to count connected players from log
    # Valheim logs "Got connection SteamID" for connects
    # and "Closing socket" or "Peer disconnect" for disconnects
    if [[ -f "$log_file" ]]; then
        local connects disconnects
        connects=$(grep -c "Got connection SteamID" "$log_file" 2>/dev/null || echo 0)
        disconnects=$(grep -c "Closing socket\|Peer disconnect" "$log_file" 2>/dev/null || echo 0)
        count=$((connects - disconnects))
        [[ $count -lt 0 ]] && count=0
    fi

    echo "$count"
}

# Track last player activity timestamp
get_last_activity_timestamp() {
    local activity_file="/tmp/valheim_last_activity"
    if [[ -f "$activity_file" ]]; then
        cat "$activity_file"
    else
        echo "0"
    fi
}

update_activity_timestamp() {
    date +%s > /tmp/valheim_last_activity
}

# Check if server is idle (no players for grace period)
is_server_idle() {
    local grace_period="${BACKUPS_IDLE_GRACE_PERIOD:-3600}"
    local player_count
    player_count=$(get_player_count)

    if [[ "$player_count" -gt 0 ]]; then
        update_activity_timestamp
        return 1  # Not idle - players connected
    fi

    # Check grace period
    local last_activity now elapsed
    last_activity=$(get_last_activity_timestamp)
    now=$(date +%s)
    elapsed=$((now - last_activity))

    if [[ "$last_activity" -eq 0 ]] || [[ $elapsed -ge $grace_period ]]; then
        return 0  # Idle
    fi

    return 1  # Within grace period
}

# Wait for server to be ready
wait_for_server_ready() {
    local timeout="${1:-120}"
    local elapsed=0

    log "Waiting for server to be ready (timeout: ${timeout}s)..."

    while [[ $elapsed -lt $timeout ]]; do
        if is_server_running; then
            log "Server process detected after ${elapsed}s"
            return 0
        fi
        sleep 5
        ((elapsed += 5))
    done

    log_error "Server failed to start within ${timeout}s"
    return 1
}

# Gracefully stop server
stop_server() {
    local timeout="${1:-120}"
    local pid
    pid=$(get_server_pid)

    if [[ -z "$pid" ]]; then
        log "Server not running"
        return 0
    fi

    log "Sending SIGTERM to server (PID: $pid)..."
    kill -TERM "$pid" 2>/dev/null

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if ! is_server_running; then
            log "Server stopped gracefully after ${elapsed}s"
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done

    log_warn "Server did not stop gracefully, sending SIGKILL..."
    kill -KILL "$pid" 2>/dev/null
    return 1
}
