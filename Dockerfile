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

# Create valheim user
RUN useradd -m -u 1000 -s /bin/bash valheim

# Create directories
RUN mkdir -p /opt/valheim/server /opt/valheim/scripts /opt/valheim/config \
    /config /bepinex /backups \
    /var/log/supervisor /var/spool/cron/crontabs \
    && chown -R valheim:valheim /opt/valheim /config /bepinex /backups

# Setup BusyBox symlinks for crond, syslogd, and logger
RUN ln -sf /bin/busybox /usr/local/bin/crond \
    && ln -sf /bin/busybox /usr/local/bin/syslogd \
    && ln -sf /bin/busybox /usr/local/bin/logger

# Locale setup
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Copy scripts
COPY --chown=valheim:valheim scripts/ /opt/valheim/scripts/
RUN chmod +x /opt/valheim/scripts/*

# Copy configuration template
COPY config/supervisord.conf.template /opt/valheim/config/

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment defaults
ENV SERVER_NAME="Valheim Server" \
    SERVER_PORT=2456 \
    WORLD_NAME="Dedicated" \
    SERVER_PASS="" \
    SERVER_PUBLIC=1 \
    CROSSPLAY=false \
    RESTART_CRON="" \
    RESTART_IF_IDLE=true \
    TZ=UTC \
    BACKUPS=true \
    BACKUPS_CRON="0 * * * *" \
    BACKUPS_MAX_AGE=3 \
    BACKUPS_MAX_COUNT=0 \
    BACKUPS_IF_IDLE=true \
    BACKUPS_IDLE_GRACE_PERIOD=3600 \
    BACKUPS_ZIP=true \
    BEPINEX=false \
    SUPERVISOR_HTTP=false \
    SUPERVISOR_HTTP_PORT=9001 \
    SUPERVISOR_HTTP_USER=admin \
    SUPERVISOR_HTTP_PASS="" \
    SYSLOG_REMOTE_HOST="" \
    SYSLOG_REMOTE_PORT=514 \
    SYSLOG_REMOTE_AND_LOCAL=true

# Expose ports
EXPOSE 2456/udp 2457/udp 9001/tcp

# Volumes
VOLUME ["/config", "/bepinex", "/backups"]

# Working directory
WORKDIR /opt/valheim

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
