#!/bin/bash
set -e

cleanup() {
    rc=$?

    echo "Disengaging maintenance mode..."
    rm -f /workspace/server/.maintenance

    echo "Waking up mc-server execution loop..."
    # Interrupt the sleep in the run.sh loop so it starts Minecraft server immediately
    ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "pkill -f 'sleep 10'" || true

    if [ "$rc" -eq 0 ]; then
        echo "[$(date)] Backup process finished successfully."
    else
        echo "[$(date)] Backup process failed with exit code $rc."
    fi

    exit "$rc"
}
trap cleanup EXIT

echo "[$(date)] Starting scheduled backup..."

echo "Engaging maintenance mode flag..."
touch /workspace/server/.maintenance

echo "Stopping mc-server..."
# Send Ctrl-C to the tmux session to interrupt the Minecraft server and stop gracefully
ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "tmux send-keys -t mc C-u stop Enter" || true

echo "Waiting for Minecraft server to exit..."
for i in {1..12}; do
    if ! ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "pgrep -x java > /dev/null"; then
        echo "Minecraft server has stopped."
        break
    fi
    sleep 5
done

echo "Running Restic Backup..."
cd /workspace/server

sh /workspace/server/restic-backup.sh "$@"
