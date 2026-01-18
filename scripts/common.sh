#!/bin/bash
# Common functions and variables for Valheim scripts

export VALHEIM_DIR="/opt/valheim/server"
export CONFIG_DIR="/saves"
export BACKUP_DIR="/backups"
export STEAMCMD="/opt/steamcmd/steamcmd.sh"
export VALHEIM_APP_ID=896660
export VALHEIM_PID_FILE="/var/run/valheim.pid"

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
get_player_count() {
    local log_file="$CONFIG_DIR/server.log"
    local count=0

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
        return 1
    fi

    local last_activity now elapsed
    last_activity=$(get_last_activity_timestamp)
    now=$(date +%s)
    elapsed=$((now - last_activity))

    if [[ "$last_activity" -eq 0 ]] || [[ $elapsed -ge $grace_period ]]; then
        return 0
    fi

    return 1
}

# Wait for server process to start
wait_for_server_ready() {
    local timeout="${1:-120}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if is_server_running; then
            return 0
        fi
        sleep 5
        ((elapsed += 5))
    done

    return 1
}

# Check if server is listening on game port
server_is_listening() {
    local server_port="${SERVER_PORT:-2456}"

    awk -v server_port="$server_port" '
        BEGIN { exit_code = 1 }
        {
            if ($1 ~ /^[0-9]/) {
                split($2, local_bind, ":")
                listening_port = sprintf("%d", "0x" local_bind[2])
                if (listening_port == server_port) {
                    exit_code = 0
                    exit
                }
            }
        }
        END { exit exit_code }
    ' /proc/net/udp* 2>/dev/null
}

# Wait for server to be online (listening on game port)
wait_for_server_online() {
    local timeout="${1:-300}"
    local server_port="${SERVER_PORT:-2456}"
    local elapsed=0

    echo "[valheim-init] Waiting for server to listen on port $server_port..."

    while [[ $elapsed -lt $timeout ]]; do
        if server_is_listening; then
            echo "[valheim-init] Server is online"
            return 0
        fi
        sleep 5
        ((elapsed += 5))
    done

    echo "[valheim-init] Timeout waiting for server to come online"
    return 1
}

# Gracefully stop server
stop_server() {
    local timeout="${1:-120}"
    local pid
    pid=$(get_server_pid)

    if [[ -z "$pid" ]]; then
        return 0
    fi

    kill -TERM "$pid" 2>/dev/null

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if ! is_server_running; then
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done

    kill -KILL "$pid" 2>/dev/null
    return 1
}
