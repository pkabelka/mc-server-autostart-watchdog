#!/bin/sh

mc_user_name="$1"
mc_server_session_name="$2"
mc_start_script_path="$3"

mc_server_pid_file="/tmp/${mc_server_session_name}.pid"

if [ ! -f "$mc_server_pid_file" ]; then
    exit 0
fi

mc_server_pid="$(cat "$mc_server_pid_file")"
if ps -p "$mc_server_pid" > /dev/null; then
    exit 0
fi

echo 'Starting a new minecraft server session.'
systemctl restart "mc-server@${mc_server_session_name}.service"
# /srv/minecraft-watchdog/mc-start-with-watchdog.sh "${mc_user_name}" "${mc_server_session_name}" "${mc_start_script_path}"
