#!/bin/bash

# Load edition (java/bedrock) and JAVA_MEMORY from the config written by install.sh
source /opt/minecraft/.config

case "$1" in
	start)
		# Start the minecraft systemd service
		sudo systemctl start minecraft
	;;
	stop)
		# Stop the minecraft systemd service
		sudo systemctl stop minecraft
	;;
	status)
		# Show the current systemd service status (running, stopped, failed, etc.)
		sudo systemctl status minecraft
	;;
	logs)
		# Java: stream live logs from the systemd journal
		# Bedrock: attach to the screen session (Ctrl+A D to detach)
		if [ "$EDITION" = "java" ]; then
			sudo journalctl -fu minecraft
		elif [ "$EDITION" = "bedrock" ]; then
			echo "Attaching to Bedrock console. Press Ctrl+A then D to detach."
			sudo -u minecraft screen -r minecraft
		else
			echo "Unexpected edition in /opt/minecraft/.config"
			exit 1
		fi
	;;
	cmd)
		# Send a command to the running server
		# Java: sent via RCON, response is printed back
		# Bedrock: sent to the screen session, check logs to see output
		if [ -z "$2" ]; then
			echo "Usage: mc-wizard cmd \"<command>\""
			echo "Example: mc-wizard cmd \"op eggsenbacon\""
			exit 0
		fi

		if [ "$EDITION" = "java" ]; then
			sudo -u minecraft /opt/minecraft/server/rcon "$2"
		elif [ "$EDITION" = "bedrock" ]; then
			sudo -u minecraft screen -S minecraft -X stuff "$2"$'\n'
			echo "Command sent. Run mc-wizard logs to see output"
		else
			echo "Unexpected edition in /opt/minecraft/.config"
			exit 1
		fi
	;;
	swap)
		# Swap the active world with one stored in /opt/minecraft/worlds/
		# The current world is moved back to /opt/minecraft/worlds/ before swapping
		# Usage: mc-wizard swap <world-name>
		# Run with no argument to list available worlds
		if [ -z "$2" ]; then
			echo "Available worlds:"
			ls /opt/minecraft/worlds/
			echo ""
			echo "To add a world: copy its folder to /opt/minecraft/worlds/"
			exit 0
		fi
		if [ ! -d "/opt/minecraft/worlds/$2" ]; then
			echo "World '$2' not found in /opt/minecraft/worlds/"
			exit 1
		fi
		sudo systemctl stop minecraft
		# Read the current level name from server.properties
		CURRENT_WORLD=$(grep "^level-name=" /opt/minecraft/server/server.properties | cut -d= -f2 | tr -d '[:space:]')
		# World lives directly in server/ for Java, inside server/worlds/ for Bedrock
		if [ "$EDITION" = "java" ]; then
			WORLD_PATH="/opt/minecraft/server"
		elif [ "$EDITION" = "bedrock" ]; then
			WORLD_PATH="/opt/minecraft/server/worlds"
		else
			echo "Unexpected edition in /opt/minecraft/.config"
			exit 1
		fi
		# Guard against malformed level-names
		if [ -z "$CURRENT_WORLD" ]; then
			echo "Could not read level-name from server.properties"
			exit 1
		fi
		# Remove stale copy of current world from worlds store if it exists, then move current world there
		if [ -d "/opt/minecraft/worlds/$CURRENT_WORLD" ]; then
			rm -rf "/opt/minecraft/worlds/$CURRENT_WORLD"
		fi
		mv "$WORLD_PATH/$CURRENT_WORLD" /opt/minecraft/worlds/
		# Update level-name in server.properties to point at the new world
		sed -i "s/^level-name=.*/level-name=$2/" /opt/minecraft/server/server.properties
		cp -r "/opt/minecraft/worlds/$2" "$WORLD_PATH/$2"
		chown -R minecraft:minecraft "$WORLD_PATH/$2"
		sudo systemctl start minecraft
	;;
	save)
		# Copy the active world to /opt/minecraft/worlds/ while the server is running
		# Java: flushes to disk via save-all then copies
		# Bedrock: uses save hold/query/resume to safely snapshot live world files
		CURRENT_WORLD=$(grep "^level-name=" /opt/minecraft/server/server.properties | cut -d= -f2 | tr -d '[:space:]')
		if [ "$EDITION" = "java" ]; then
			WORLD_PATH="/opt/minecraft/server"
			mc-wizard cmd "save-all"
			sleep 3
		elif [ "$EDITION" = "bedrock" ]; then
			WORLD_PATH="/opt/minecraft/server/worlds"
			mc-wizard cmd "save hold"
			sleep 2
			# Poll until the server confirms world files are ready to copy
			until sudo -u minecraft screen -S minecraft -X hardcopy /tmp/mc-screen.txt && grep -q "ready to be copied" /tmp/mc-screen.txt; do
				mc-wizard cmd "save query"
				sleep 2
			done
		else
			echo "Unexpected edition in /opt/minecraft/.config"
			exit 1
		fi
		# Guard against malformed level-names
		if [ -z "$CURRENT_WORLD" ]; then
			echo "Could not read level-name from server.properties"
			exit 1
		fi

		if [ -d "/opt/minecraft/worlds/$CURRENT_WORLD" ]; then
			rm -rf "/opt/minecraft/worlds/$CURRENT_WORLD"
		fi
		cp -r "$WORLD_PATH/$CURRENT_WORLD" "/opt/minecraft/worlds/$CURRENT_WORLD"
		# Tell Bedrock to resume normal world writes after the copy
		if [ "$EDITION" = "bedrock" ]; then
			mc-wizard cmd "save resume"
		fi
	;;
	backup)
		echo "Backup not yet implemented"
	;;
	help)
		echo ""
		echo "mc-wizard — Minecraft server management CLI"
		echo ""
		echo "Commands:"
		echo "  start              Start the server"
		echo "  stop               Stop the server"
		echo "  status             Show server status"
		echo "  logs               Stream live logs (Java) or attach to console (Bedrock)"
		echo "  cmd \"<command>\"    Send a command to the server"
		echo "  save               Copy the active world to /opt/minecraft/worlds/ (server stays running)"
		echo "  swap <world>       Swap the active world. Run with no argument to list available worlds"
		echo "                     To add a world: copy its folder to /opt/minecraft/worlds/"
		echo "  backup             Back up the world to S3 (requires BACKUP_BUCKET to be set)"
		echo "  help               Show this message"
		echo ""
		echo "Edition: $EDITION"
		echo "Config:  /opt/minecraft/.config"
		echo "Worlds:  /opt/minecraft/worlds/"
		echo ""
	;;
	*)
		echo "Usage: mc-wizard [start|stop|status|logs|swap|save|backup|cmd|help]"
	;;
esac
