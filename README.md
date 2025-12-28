# Minecraft Server Autostart Watchdog

## Installation

The watchdog depends on `firejail` and `restic`. The firejail profile for
minecraft server must be placed in `/etc/firejail`.

Move the watchdog dir to `/srv/minecraft-watchdog`.

```sh
ln -t /etc/systemd/system /srv/minecraft-watchdog/*.service
ln -t /etc/systemd/system /srv/minecraft-watchdog/*.timer
systemctl daemon-reload
```

Create a user that will run the minecraft server(s) (e.g. `mc-vanilla`):

```sh
useradd --no-create-home mc-vanilla
# or if you want to customize its tmux
useradd --create-home mc-vanilla
```

Create a firejail wrapper for starting the server in the server dir, for
example: `/srv/minecraft-vanilla-server/firejail-start.sh`:

```sh
#!/bin/sh

serverJar="fabric-server-mc.1.19.2-loader.0.14.11-launcher.0.11.1.jar"
# FroggeMC's ZGC flags
# https://github.com/FroggeMC/MC-Java-Flags
firejail --profile=minecraft-server --whitelist=/srv/minecraft-vanilla-server java -server -Xms6G -Xmx6G -XX:+IgnoreUnrecognizedVMOptions -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:-OmitStackTraceInFastThrow -XX:+ShowCodeDetailsInExceptionMessages -XX:+DisableExplicitGC -XX:-UseParallelGC -XX:-UseParallelOldGC -XX:+PerfDisableSharedMem -XX:+UseZGC -XX:-ZUncommit -XX:ZUncommitDelay=300 -XX:ZCollectionInterval=5 -XX:ZAllocationSpikeTolerance=2.0 -XX:+AlwaysPreTouch -XX:+UseTransparentHugePages -XX:LargePageSizeInBytes=2M -XX:+UseLargePages -XX:+ParallelRefProcEnabled -jar "$serverJar" -nogui
```

Think of a unique (unique for the systemd service) tmux session name that the
service will use to manage the server. For example: `minecraft-vanilla`.

Create an env file with the session name in `/srv/minecraft-watchdog`:

```sh
cp /srv/minecraft-watchdog /srv/minecraft-watchdog/minecraft-vanilla.env
# vim /srv/minecraft-watchdog/minecraft-vanilla.env
```

The minecraft server files must be owned by the minecraft server account:

```sh
chown -R mc-vanilla:mc-vanilla /srv/minecraft-vanilla-server
```

The server can now be manually started/stopped with:

```sh
systemctl start mc-server@minecraft-vanilla.service
systemctl stop mc-server@minecraft-vanilla.service
```

Access the server console with:

```sh
su - mc-vanilla
tmux attach
```

## Set up restic backups

Initialize the restic repository:

```sh
repository_path="/srv/minecraft-vanilla-backups"
password_file=~/.keys/minecraft-vanilla-restic.txt
restic -r "$repository_path" --password-file "$password_file" init
```

`restic-backup.sh`:

```sh
#!/bin/sh

minecraft_version="1.19.2"
repository_path="/srv/minecraft-vanilla-backups"
password_file=~/.keys/minecraft-vanilla-restic.txt

nodynmap=$(restic -r "$repository_path" --password-file "$password_file" snapshots --tag nodynmap --latest 1 | tac | sed '3q;d' | cut -d' ' -f1)
dynmap=$(restic -r "$repository_path" --password-file "$password_file" snapshots --tag dynmap --latest 1 | tac | sed '3q;d' | cut -d' ' -f1)

restic -r "$repository_path" \
    --password-file "$password_file" \
    backup \
    --host archlinux \
    --parent "$nodynmap" \
    --exclude-file=restic-excludes.txt \
    --tag "$minecraft_version" \
    --tag nodynmap "$@"

restic -r "$repository_path" \
    --password-file "$password_file" \
    backup \
    --host archlinux \
    --parent "$dynmap" \
    --tag "$minecraft_version" \
    --tag dynmap "$@"
```

`restic-excludes.txt`:

```sh
dynmap/*
mods/Dynmap-*.jar
```

## Start the watchdog and backup service

```sh
systemctl enable --now mc-server-watchdog@minecraft-vanilla.timer
systemctl enable --now mc-server-backup@minecraft-vanilla.timer
```

The watchdog runs every 5 minutes to check if the server should be running and
starts it if's not running, unless in was stopped with:

```sh
systemctl stop mc-server@minecraft-vanilla.service
```

The backup service runs every day at 05:00 in the morning. It stops the server,
runs backup and starts the server again.
