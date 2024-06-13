#!/bin/sh

mc_user_name="$1"
mc_server_session_name="$2"

su - -s /bin/bash -c '[ ! -z "$(tmux ls -F "#{?#{==:#{session_name},"${1}"},#{session_name},}")" ] && tmux send-keys -t "$1" C-c ENTER' "$mc_user_name" mc-bash "$mc_server_session_name"
sleep 20s

rm "/tmp/${mc_server_session_name}.pid"
