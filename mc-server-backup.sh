#!/bin/sh

mc_server_session_name="$1"
mc_backup_script_path="$2"

if [ -z "$mc_server_session_name" ] || [ ! -f "$mc_backup_script_path" ]; then
    exit 1
fi

mc_server_dir="$(dirname -- "$(readlink -m -- "$mc_backup_script_path")")"

echo 'Stopping minecraft server.'
systemctl stop "mc-server@${mc_server_session_name}.service"

echo 'Backing up minecraft server.'
(cd "$mc_server_dir" && $mc_backup_script_path '.')

echo 'Starting minecraft server.'
systemctl start "mc-server@${mc_server_session_name}.service"
