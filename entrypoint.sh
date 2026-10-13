#!/bin/bash
set -e

if [ "$ROLE" = "server" ]; then
    echo "Starting Server Mode..."

    cd /workspace/server
    rm -f /workspace/server/.shutdown

    # Set up internal SSH keys for mc-backup to connect
    cp /root/.ssh/id_rsa.pub /root/.ssh/internal_authorized_keys
    chmod 600 /root/.ssh/internal_authorized_keys

    # Set up SSH for console access
    echo "Starting SSH daemon on port 2222..."
    /usr/sbin/sshd -f /etc/ssh/sshd_config

    # Create the robust Minecraft server loop wrapper
    cat << 'EOF' > /workspace/run.sh
#!/bin/bash
while [ ! -f /workspace/server/.shutdown ]; do
    if [ -f /workspace/server/.maintenance ]; then
        echo "[$(date)] Maintenance mode active. Waiting 10 seconds..."
        sleep 10
    else
        echo "[$(date)] Starting Minecraft server..."
        bash start.sh
        if [ -f /workspace/server/.shutdown ]; then
            break
        fi
        echo "[$(date)] Minecraft server exited. Restarting in 5 seconds unless maintenance flag is set..."
        sleep 5
    fi
done
EOF
    chmod +x /workspace/run.sh

    graceful_shutdown() {
        echo "[$(date)] Shutdown signal received. Stopping Minecraft server..."
        touch /workspace/server/.shutdown
        tmux send-keys -t mc C-c
        while pgrep -x java > /dev/null; do
            sleep 1
        done
        tmux kill-server 2>/dev/null || true
        echo "[$(date)] Minecraft server stopped."
        exit 0
    }
    trap graceful_shutdown SIGTERM SIGINT

    echo "Starting Minecraft server in tmux..."
    tmux new-session -s mc -d "/workspace/run.sh"

    echo "Server running in background. Keep-alive active."
    # allows bash to immediately interrupt when trapped signal is arrives
    while true; do
        sleep 1 &
        wait $!
    done

# ---------------------------------------------------------------------------

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
