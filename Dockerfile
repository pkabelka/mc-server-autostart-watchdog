FROM debian:bookworm-slim AS builder

# Install tools required just to fetch the MSH binary
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download MSH binary
RUN LATEST_MSH_URL=$(curl -s https://api.github.com/repos/gekware/minecraft-server-hibernation/releases/latest | jq -r '.assets[] | select(.name | endswith("linux-amd64.bin")) | .browser_download_url') && \
    if [ -z "$LATEST_MSH_URL" ] || [ "$LATEST_MSH_URL" = "null" ]; then echo "Failed to find MSH download URL"; exit 1; fi && \
    curl -L -o /msh "$LATEST_MSH_URL"

FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    tmux \
    openssh-server \
    restic \
    rclone \
    curl \
    jq \
    cron \
    ca-certificates \
    procps \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy MSH from the builder stage with executable permissions
COPY --from=builder --chmod=755 /msh /usr/local/bin/msh

# Generate SSH keys and configure rootless operation in a single layer
RUN mkdir -p /root/.ssh /run/sshd /etc/ssh/sshd_config.d && \
    ssh-keygen -A && \
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa && \
    printf "Port 2222\n\
PermitRootLogin yes\n\
AuthorizedKeysFile .ssh/authorized_keys /root/.ssh/internal_authorized_keys\n" >> /etc/ssh/sshd_config && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# Copy scripts directly with the correct ownership and permissions
COPY --chmod=755 entrypoint.sh backup.sh /usr/local/bin/

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
