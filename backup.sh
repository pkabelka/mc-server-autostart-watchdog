#!/bin/bash
set -e

echo "[$(date)] Starting scheduled backup..."

echo "Engaging maintenance mode flag..."
touch /workspace/server/.maintenance

echo "Stopping MSH on mc-server to gracefully halt the Minecraft server..."
# Send Ctrl-C to the tmux session to interrupt MSH and stop gracefully
ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "tmux send-keys -t mc C-c" || true

# Wait for MSH to completely exit
echo "Waiting for MSH to exit..."
for i in {1..12}; do
    if ! ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "pgrep '^msh$' > /dev/null"; then
        echo "MSH has stopped."
        break
    fi
    sleep 5
done

echo "Running Restic Backup..."
cd /workspace/server

# Initialize the repository if it doesn't exist yet
restic init || true

# Run the backup using the rclone backend
minecraft_version="$(jq '.Server.Version' msh-config.json)"

nodynmap=$(restic snapshots --tag nodynmap --latest 1 | tac | sed '3q;d' | cut -d' ' -f1)
dynmap=$(restic snapshots --tag dynmap --latest 1 | tac | sed '3q;d' | cut -d' ' -f1)

restic \
    backup . \
    --host archlinux \
    --parent "$nodynmap" \
    --exclude-file=restic-excludes.txt \
    --tag "$minecraft_version" \
    --tag nodynmap

restic \
    backup . \
    --host archlinux \
    --parent "$dynmap" \
    --tag "$minecraft_version" \
    --tag dynmap

echo "Disengaging maintenance mode..."
rm -f /workspace/server/.maintenance

echo "Waking up mc-server execution loop..."
# Interrupt the sleep in the run-msh.sh loop so it starts MSH immediately
ssh -p 2222 -o StrictHostKeyChecking=no root@mc-server "pkill -f 'sleep 10'" || true

echo "[$(date)] Backup process finished successfully."
