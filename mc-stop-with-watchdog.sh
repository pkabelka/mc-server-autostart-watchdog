#!/bin/sh

mc_user_name="$1"
mc_server_session_name="$2"

if [ -z "$mc_server_session_name" ] || [ -z "$mc_user_name" ]; then
    exit 1
fi

mc_server_pid_file="/tmp/${mc_server_session_name}.pid"
mc_server_pid="$(cat "$mc_server_pid_file")"

rm -f "$mc_server_pid_file"
su - -s /bin/bash -c '[ ! -z "$(tmux ls -F "#{?#{==:#{session_name},"${1}"},#{session_name},}")" ] && tmux send-keys -t "$1" C-c' "$mc_user_name" mc-bash "$mc_server_session_name"

while ps -p "$mc_server_pid" > /dev/null 2>&1; do
    sleep 1
done
