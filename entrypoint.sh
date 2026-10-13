#!/bin/bash
set -e

if [ "$ROLE" = "server" ]; then
    echo "Starting Server Mode..."

    cd /workspace/server

    # Set up internal SSH keys for mc-backup to connect
    cp /root/.ssh/id_rsa.pub /root/.ssh/internal_authorized_keys
    chmod 600 /root/.ssh/internal_authorized_keys

    # Set up SSH for console access
    echo "Starting SSH daemon on port 2222..."
    /usr/sbin/sshd -f /etc/ssh/sshd_config

    # Create the robust Minecraft server loop wrapper
    cat << 'EOF' > /workspace/run.sh
#!/bin/bash
while true; do
    if [ -f /workspace/server/.maintenance ]; then
        echo "[$(date)] Maintenance mode active. Waiting 10 seconds..."
        sleep 10
    else
        echo "[$(date)] Starting Minecraft server..."
        sh start.sh
        echo "[$(date)] Minecraft server exited. Restarting in 5 seconds unless maintenance flag is set..."
        sleep 5
    fi
done
EOF
    chmod +x /workspace/run.sh

    echo "Starting Minecraft server in tmux..."
    tmux new-session -s mc -d "/workspace/run.sh"

    echo "Server running in background. Keep-alive active."
    exec tail -f /dev/null

elif [ "$ROLE" = "backup" ]; then
    echo "Starting Backup Mode..."

    echo "Configuring cron for backups..."
    echo "15 3 * * * /usr/local/bin/backup.sh > /proc/1/fd/1 2>/proc/1/fd/2" | crontab -

    echo "Starting cron daemon..."
    exec cron -f

else
    echo "Error: ROLE environment variable must be set to 'server' or 'backup'."
    exit 1
fi
