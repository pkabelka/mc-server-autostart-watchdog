#!/bin/sh

mc_user_name="$1"
mc_server_session_name="$2"
mc_start_script_path="$3"

if [ -z "$mc_server_session_name" ] || [ -z "$mc_user_name" ] || [ -z "$mc_start_script_path" ]; then
    exit 1
fi

mc_server_dir="$(dirname -- "$(readlink -m -- "$mc_start_script_path")")"

su - -s /bin/bash -c '[ -z "$(tmux ls -F "#{?#{==:#{session_name},"${1}"},#{session_name},}")" ] && tmux new-session -s "$1" -d' "$mc_user_name" mc-bash "$mc_server_session_name"
su - -s /bin/bash -c '[ ! -z "$(tmux ls -F "#{?#{==:#{session_name},"${1}"},#{session_name},}")" ] && tmux send-keys -t "$1" "$2" ENTER' "$mc_user_name" mc-bash "$mc_server_session_name" "cd ${mc_server_dir}"
su - -s /bin/bash -c '[ ! -z "$(tmux ls -F "#{?#{==:#{session_name},"${1}"},#{session_name},}")" ] && tmux send-keys -t "$1" "$2" ENTER' "$mc_user_name" mc-bash "$mc_server_session_name" "$mc_start_script_path"
sleep 5s

firejail --list | awk -F':' -v mc_user_name="$mc_user_name" '{if ($2 == mc_user_name) {print $1}}' > "/tmp/${mc_server_session_name}.pid"
