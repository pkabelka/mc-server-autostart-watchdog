# Containerized Minecraft Server Autostart Watchdog

A rootless container architecture for running a Minecraft server with automatic hibernation (via [MSH](https://github.com/gekware/minecraft-server-hibernation)) and automated daily Restic backups (via Rclone).

This setup utilizes two isolated containers (`mc-server` and `mc-backup`) orchestrated by Docker Compose. The server container runs the Minecraft Server Hibernation (MSH) wrapper inside a `tmux` session, accessible securely via an internal SSH server.

## Features
* **Rootless Compatible:** Designed to run in rootless Podman/Docker.
* **Auto-Hibernation:** MSH automatically pauses the server when no players are online to save resources.
* **Isolated Backups:** A dedicated backup container wakes up daily at 3:15 AM, gracefully halts the server via MSH, performs a cloud backup using Restic, and resumes the server.
* **Console Access:** Attach directly to the active Minecraft console securely over SSH.

## Prerequisites

Before deploying the stack, you need to prepare a working directory (separate from the repository clone) to hold your secrets and configuration files.

You will need:
1. An SSH key pair for console access (e.g., `mcserver.pem` and its public key `mcserver.pem.pub`).
2. An `rclone.conf` configured with your cloud storage provider.
3. A `restic-password.txt` file containing your Restic repository password.
4. Your existing Minecraft server files (e.g., `server.jar`, `world`, `eula.txt`) located in a dedicated directory on your host.

## Directory Structure Setup

It is highly recommended to run the compose commands from a "secrets" or "deployment" directory, referencing the compose file remotely. This keeps your sensitive files out of the git repository.

Example setup:
```text
/home/user/
├── mc-server-autostart-watchdog/  <-- (This repository clone)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── ...
├── my-mc-deployment/              <-- (Your execution directory)
│   ├── mcserver.pem.pub           <-- (Your public SSH key)
│   ├── rclone.conf                <-- (Your rclone config)
│   └── restic-password.txt        <-- (Your restic password)
└── minecraft-vanilla/             <-- (Your actual Minecraft server files)
```

## Configuration

Before starting, review the `docker-compose.yml` file in the repository.

1. **Minecraft Data Mount:** Ensure the volume path matches your actual server files path. By default, it is set to:
   `- /media/shared/minecraft-vanilla:/workspace/server`
2. **Restic Repository:** Update the `RESTIC_REPOSITORY` environment variable in the `mc-backup` service to point to your rclone remote (e.g., `rclone:mcdropbox:minecraft-backups`).

## Usage

Navigate to your deployment directory (where your secret files are) and execute the compose file from the repository.

### Starting the Server
```bash
cd ~/my-mc-deployment
docker compose -f ../mc-server-autostart-watchdog/docker-compose.yml up -d
```
*Note: If you use Podman, replace `docker compose` with `podman-compose`.*

### Stopping the Server
```bash
cd ~/my-mc-deployment
docker compose -f ../mc-server-autostart-watchdog/docker-compose.yml down
```

## Connecting to the Console

The Minecraft server runs inside a `tmux` session within the container. To access it, you SSH into the container on port `2222` using the private key that corresponds to the `authorized_keys` file you mounted.

Run the following command from your host machine:

```bash
ssh -i mcserver.pem -p 2222 -o StrictHostKeyChecking=no -t root@127.0.0.1 "tmux attach -t mc"
```

* **To exit the console and leave the server running:** Press `Ctrl+b`, then release and press `d` (detach).
* **Do NOT press `Ctrl+c`** unless you intend to kill the MSH wrapper and shut down the server.
