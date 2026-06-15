#!/bin/bash
# ── CONFIGURE ME ──────────────────────────
EDITION="java"   # change to "bedrock" for Bedrock edition
JAVA_MEMORY="2G"
GAMEMODE="survival"
DIFFICULTY="easy"
SEED=""
MAX_PLAYERS="20"
MOTD="My Server"
BEDROCK_URL="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.26.23.1.zip"
JAVA_URL="https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar"
# ──────────────────────────────────────────

# Install Packages:
apt update
mkdir -p /opt/minecraft/server
mkdir -p /opt/minecraft/worlds

if [ "$EDITION" = "java" ]; then
	# Install Java:
	apt install -y openjdk-25-jre-headless
	wget -O /opt/minecraft/server/rcon https://raw.githubusercontent.com/KieranGliver/mc-server/main/rcon/rcon-linux
	chmod +x /opt/minecraft/server/rcon
	# Download java server:
	wget -P /opt/minecraft/server $JAVA_URL 
	echo "eula=true" > /opt/minecraft/server/eula.txt
	wget -O /opt/minecraft/server/server.properties https://raw.githubusercontent.com/KieranGliver/mc-server/main/minecraft/java-server.properties.template
elif [ "$EDITION" = "bedrock" ]; then
	apt install -y unzip
	apt install -y screen
	# Download bedrock server:
	wget -O /tmp/bedrock-server.zip $BEDROCK_URL 
	unzip /tmp/bedrock-server.zip -d /opt/minecraft/server
	rm /tmp/bedrock-server.zip
	wget -O /opt/minecraft/server/server.properties https://raw.githubusercontent.com/KieranGliver/mc-server/main/minecraft/bedrock-server.properties.template
else
	echo "Unknown edition: $EDITION"
	exit 1
fi

sed -i "s/GAMEMODE_PLACEHOLDER/$GAMEMODE/g" /opt/minecraft/server/server.properties
sed -i "s/DIFFICULTY_PLACEHOLDER/$DIFFICULTY/g" /opt/minecraft/server/server.properties
sed -i "s/SEED_PLACEHOLDER/$SEED/g" /opt/minecraft/server/server.properties
sed -i "s/MAX_PLAYERS_PLACEHOLDER/$MAX_PLAYERS/g" /opt/minecraft/server/server.properties
sed -i "s/MOTD_PLACEHOLDER/$MOTD/g" /opt/minecraft/server/server.properties

echo "EDITION=$EDITION" > /opt/minecraft/.config
echo "JAVA_MEMORY=$JAVA_MEMORY" >> /opt/minecraft/.config

wget -O /opt/minecraft/server/start.sh https://raw.githubusercontent.com/KieranGliver/mc-server/main/minecraft/start.sh
chmod +x /opt/minecraft/server/start.sh


useradd --system --no-create-home --shell /usr/sbin/nologin minecraft
chown -R minecraft:minecraft /opt/minecraft

wget -O /etc/systemd/system/minecraft.service https://raw.githubusercontent.com/KieranGliver/mc-server/main/systemd/minecraft.service
systemctl daemon-reload
systemctl enable --now minecraft
