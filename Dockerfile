FROM debian:bookworm-slim

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    lib32gcc-s1 \
    lib32stdc++6 \
    libsdl2-2.0-0 \
    libatomic1 \
    libpulse0 \
    locales \
    procps \
    busybox \
    supervisor \
    cron \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install steamcmd
RUN mkdir -p /opt/steamcmd \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar -xzC /opt/steamcmd \
    && chmod -R +x /opt/steamcmd \
    && /opt/steamcmd/steamcmd.sh +quit

# Create directories
RUN mkdir -p /opt/valheim/server /opt/valheim/scripts \
    /saves /backups \
    /var/log/supervisor /var/spool/cron/crontabs

# Setup BusyBox symlink for crond
RUN ln -sf /bin/busybox /usr/local/bin/crond

# Locale setup
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Copy scripts
COPY scripts/ /opt/valheim/scripts/
RUN chmod +x /opt/valheim/scripts/*

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment defaults
ENV SERVER_NAME="Valheim Server" \
    SERVER_PORT=2456 \
    WORLD_NAME="Dedicated" \
    SERVER_PASS="secret" \
    SERVER_PUBLIC=1 \
    CROSSPLAY=false \
    RESTART_CRON="0 5 * * *" \
    RESTART_IF_IDLE=true \
    TZ=UTC \
    BACKUPS=true \
    BACKUPS_CRON="*/15 * * * *" \
    BACKUPS_MAX_AGE=3 \
    BACKUPS_MAX_COUNT=24 \
    BACKUPS_IF_IDLE=true \
    BACKUPS_IDLE_GRACE_PERIOD=3600 \
    BACKUPS_COMPRESS=true \
    BEPINEX=false \
    SUPERVISOR_HTTP=false \
    SUPERVISOR_HTTP_PORT=9001 \
    SUPERVISOR_HTTP_USER=admin \
    SUPERVISOR_HTTP_PASS="changeme"

# Expose ports
EXPOSE 2456/udp 2457/udp 9001/tcp 2457/tcp

# Volumes
VOLUME ["/opt/valheim/server", "/saves", "/backups"]

# Working directory
WORKDIR /opt/valheim

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
