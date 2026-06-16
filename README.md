# mc-server

A zero-dependency Minecraft server setup for any Ubuntu cloud instance. Paste one script into User Data and your server is running, managed by systemd, and auto-restarts on crash or reboot.

Supports both **Java Edition** and **Bedrock Edition**. Includes a Go-based RCON client for Java and a CLI wizard for managing the server after launch.

**Tested on:** AWS EC2. Should work on GCP, Azure, DigitalOcean, and any other provider running Ubuntu — untested.

---

## What's Included

| File | Description |
|------|-------------|
| `install.sh` | One-shot installer — configure at the top, paste into cloud User Data |
| `systemd/minecraft.service` | systemd service — auto-start on boot, restart on crash |
| `minecraft/start.sh` | Starts the correct server binary based on edition |
| `rcon/` | Go CLI tool for sending RCON commands to a Java server |
| `mc-wizard.sh` | CLI for managing the server after install |

---

## Requirements

- Ubuntu 22.04 or 24.04
- The following ports open inbound in your firewall or cloud security group:

| Edition | Port  | Protocol |
|---------|-------|----------|
| Java    | 25565 | TCP      |
| Bedrock | 19132 | UDP      |
| SSH     | 22    | TCP      |

---

## Quick Start

### 1. Launch an Ubuntu instance

Any cloud provider works. Minimum recommended specs:
- **Java:** t3.small (2GB RAM) — set `JAVA_MEMORY` to `1G`
- **Bedrock:** t3.micro (1GB RAM) is sufficient

### 2. Open the required port

In your cloud provider's firewall or security group, open the port for your edition (see table above). You will also need port 22 open for SSH.

### 3. Configure `install.sh`

Edit the variables at the top of `install.sh`:

```bash
# ── CONFIGURE ME ──────────────────────────
EDITION="java"        # change to "bedrock" for Bedrock edition
JAVA_MEMORY="2G"      # max RAM for the Java server (ignored for Bedrock)
GAMEMODE="survival"
DIFFICULTY="easy"
SEED=""               # leave empty for a random world
MAX_PLAYERS="20"
MOTD="My Server"
BEDROCK_URL="https://..."   # paste Bedrock download URL from minecraft.net
JAVA_URL="https://..."      # paste Java server.jar URL from minecraft.net
# ──────────────────────────────────────────
```

Download URLs:
- **Java:** https://www.minecraft.net/en-us/download/server
- **Bedrock:** https://www.minecraft.net/en-us/download/server/bedrock

### 4. Paste into User Data

Copy the full contents of `install.sh` and paste it into your instance's User Data field before launch. On AWS this is under *Advanced Details → User Data* in the EC2 launch wizard.

The script will run automatically on first boot and:
- Install dependencies
- Download and configure the server
- Write server.properties from your settings
- Install and enable the systemd service
- Install `mc-wizard` globally

### 5. Verify

SSH into the instance once it's running and check the server status:

```bash
mc-wizard status
```

---

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `EDITION` | `java` | `java` or `bedrock` |
| `JAVA_MEMORY` | `2G` | JVM heap size — set to ~half your instance RAM |
| `GAMEMODE` | `survival` | `survival`, `creative`, or `adventure` |
| `DIFFICULTY` | `easy` | `peaceful`, `easy`, `normal`, or `hard` |
| `SEED` | *(empty)* | World seed — leave empty for random |
| `MAX_PLAYERS` | `20` | Maximum concurrent players |
| `MOTD` | `My Server` | Server name shown in the server list |
| `JAVA_URL` | — | Direct download URL for the Java server.jar |
| `BEDROCK_URL` | — | Direct download URL for the Bedrock server zip |

---

## mc-wizard

After install, `mc-wizard` is available globally on the instance.

```
mc-wizard <command>
```

| Command | Description |
|---------|-------------|
| `start` | Start the server |
| `stop` | Stop the server |
| `status` | Show systemd service status |
| `logs` | Stream live logs (Java) or attach to the server console (Bedrock) |
| `cmd "<command>"` | Send a command to the server |
| `save` | Snapshot the active world to `/opt/minecraft/worlds/` while the server is running |
| `swap <world>` | Swap the active world — run with no argument to list available worlds |
| `backup` | Back up the world to S3 *(coming soon)* |
| `help` | Show all commands with descriptions |

### Examples

```bash
mc-wizard start
mc-wizard cmd "op eggsenbacon"
mc-wizard cmd "time set day"
mc-wizard swap my-old-world
mc-wizard save
```

> **Note:** On Java, `cmd` sends via RCON and prints the response. On Bedrock, the command is sent to the server console — run `mc-wizard logs` to see the output.

---

## World Management

Worlds are stored in `/opt/minecraft/worlds/` on the instance. The active world is whatever `level-name` is set to in `server.properties`.

### Upload a world

```bash
scp -r -i your-key.pem ./my-world ubuntu@<instance-ip>:/opt/minecraft/worlds/
```

### Swap to a different world

```bash
mc-wizard swap my-world
```

The current active world is automatically moved back to `/opt/minecraft/worlds/` before the swap, so nothing is lost.

### Save the active world

```bash
mc-wizard save
```

This safely snapshots the active world to `/opt/minecraft/worlds/` while the server keeps running. Java uses `save-all` to flush to disk first. Bedrock uses `save hold/query/resume` to guarantee a consistent snapshot.

---

## Architecture

- **systemd** manages the server process — it starts on boot and restarts automatically if the server crashes
- **Java** runs directly under systemd; commands are sent via a custom RCON client (`rcon/`) written in Go
- **Bedrock** runs inside a GNU screen session so console commands can be sent without attaching interactively
- Install config is written to `/opt/minecraft/.config` and sourced by `start.sh` and `mc-wizard` at runtime
- Server files live at `/opt/minecraft/server/`, worlds at `/opt/minecraft/worlds/`
- The server runs as a locked-down `minecraft` system user with no login shell
