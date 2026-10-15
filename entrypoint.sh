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

    cat << 'EOF' > ~/.tmux.conf
set -g base-index 1
setw -g pane-base-index 1

# use vi keybinds in windows
setw -g mode-keys vi
# use emacs keybinds in status bar command prompt
set -g status-keys emacs

set-option -g default-terminal screen-256color

# Enable truecolor output in tmux running inside xterm and kitty
# set -as terminal-features ",xterm*:RGB"
# Enable truecolor output in nested tmux running inside xterm and kitty
set -as terminal-features ",xterm*:RGB,screen-256color:RGB,tmux-256color:RGB"
set-environment -g COLORTERM truecolor

set -g history-limit 10000

bind-key : command-prompt
bind-key r refresh-client
bind-key Z clear-history

# use vim-like keys for splits and windows
bind-key v split-window -h
bind-key V split-window -h -c "#{pane_current_path}"
bind-key s split-window -v
bind-key S split-window -v -c "#{pane_current_path}"
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

# send clear command
bind C-l send-keys 'C-l'

bind-key + select-layout main-horizontal
bind-key = select-layout main-vertical
set-window-option -g other-pane-height 25
set-window-option -g other-pane-width 80
bind-key enter next-layout
bind-key C-o rotate-window

bind-key bspace last-window
bind-key a last-pane

# swap windows
bind-key N swap-window -d -t +1
bind-key P swap-window -d -t -1

# swap panes
bind-key H swap-pane -s '{left-of}'
bind-key J swap-pane -s '{down-of}'
bind-key K swap-pane -s '{up-of}'
bind-key L swap-pane -s '{right-of}'

# join a window as a pane to the active window
bind-key C-g choose-window 'join-pane -h -s "%%"'

bind-key q display-panes
set-window-option -g display-panes-time 1500

bind-key c new-window
bind-key C-c new-window -c "#{pane_current_path}"

bind-key [ copy-mode
bind-key ] paste-buffer

bind-key C-t set -w synchronize-panes

# Use clipboard
set -g set-clipboard on

# Setup 'v' to begin selection as in Vim
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send -X copy-selection-and-cancel

# Update default binding of `Enter` to also use copy-pipe
unbind -T copy-mode-vi Enter
bind-key -T copy-mode-vi Enter send -X copy-selection-and-cancel

# Status Bar
set-option -g status-interval 1
set-option -g status-left ''
set-option -g status-right '%H:%M'
set-window-option -g window-status-current-style fg=magenta
set-option -g status-fg white

# Status Bar colors
set-option -g status-bg black
set-option -g pane-active-border-style fg=yellow
set-option -g pane-border-style fg=cyan

# Set window notifications
setw -g monitor-activity on
set -g visual-activity off

# Allow the arrow key to be used immediately after changing windows
set-option -g repeat-time 0
EOF

    graceful_shutdown() {
        echo "[$(date)] Shutdown signal received. Stopping Minecraft server..."
        touch /workspace/server/.shutdown
        tmux send-keys -t mc C-u stop Enter
        while pgrep -x java > /dev/null; do
            sleep 1
        done
        tmux kill-server 2>/dev/null || true
        rm -f /workspace/server/.shutdown
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

    BACKUP_CRON_SCHEDULE="${BACKUP_CRON_SCHEDULE:-15 3 * * *}"
    BACKUP_LOG_FILE="/var/log/mc-backup.log"

    echo "Configuring cron for backups..."
    echo "15 3 * * * /usr/local/bin/backup.sh > /proc/1/fd/1 2>/proc/1/fd/2" | crontab -
    {
        echo "SHELL=/bin/sh"
        echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        echo "MAILTO=\"\""
        echo "RESTIC_PASSWORD_FILE=$(printf %q "$RESTIC_PASSWORD_FILE")"
        echo "RESTIC_REPOSITORY=$(printf %q "$RESTIC_REPOSITORY")"
        echo "${BACKUP_CRON_SCHEDULE} /usr/local/bin/backup.sh >> ${BACKUP_LOG_FILE} 2>&1"
    } | crontab -

    # Cron does not write job output to container stdout, instead it forwards
    # stdout and stderr to an MTA.
    # Writing a log file and streaming it allows the container logs to be
    # populated with the cron output.
    mkdir -p "$(dirname "$BACKUP_LOG_FILE")"
    : > "$BACKUP_LOG_FILE"
    tail -F -n +1 "$BACKUP_LOG_FILE" &

    echo "Starting cron daemon..."
    exec cron -f

else
    echo "Error: ROLE environment variable must be set to 'server' or 'backup'."
    exit 1
fi
