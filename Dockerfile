FROM debian:trixie-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public -o /etc/apt/keyrings/adoptium.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        temurin-25-jre \
        tmux \
        openssh-server \
        restic \
        rclone \
        jq \
        cron \
        procps \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Generate SSH keys and configure rootless operation in a single layer
RUN mkdir -p /root/.ssh /run/sshd /etc/ssh/sshd_config.d && \
    ssh-keygen -A && \
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa && \
    printf "Port 2222\n\
PermitRootLogin yes\n\
StrictModes no\n\
AuthorizedKeysFile .ssh/authorized_keys /root/.ssh/internal_authorized_keys\n" >> /etc/ssh/sshd_config && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# Copy scripts directly with the correct ownership and permissions
COPY --chmod=755 entrypoint.sh backup.sh /usr/local/bin/

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
