#!/bin/bash
# ── CONFIGURE ME ──────────────────────────
EDITION="java"   # change to "bedrock" for Bedrock edition
BEDROCK_URL="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.26.23.1.zip"
JAVA_URL="https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar"
# ──────────────────────────────────────────

# Install Packages:
apt update
apt install -y unzip

mkdir -p /opt/minecraft/server
mkdir -p /opt/minecraft/worlds

if [ "$EDITION" = "java" ]; then
	# Install Java:
	apt install -y openjdk-25-jre-headless
	# Download java server:
	wget -P /opt/minecraft/server $JAVA_URL 
	echo "eula=true" > /opt/minecraft/server/eula.txt
elif [ "$EDITION" = "bedrock" ]; then
	# Download bedrock server:
	wget -O /tmp/bedrock-server.zip $BEDROCK_URL 
	unzip /tmp/bedrock-server.zip -d /opt/minecraft/server
	rm /tmp/bedrock-server.zip
else
	echo "Unknown edition: $EDITION"
	exit 1
fi

echo "EDITION=$EDITION" > /opt/minecraft/.config

wget -O /opt/minecraft/server/start.sh https://raw.githubusercontent.com/KieranGliver/mc-server/main/start.sh
chmod +x /opt/minecraft/server/start.sh

useradd --system --no-create-home --shell /usr/sbin/nologin minecraft
chown -R minecraft:minecraft /opt/minecraft

wget -O /etc/systemd/system/minecraft.service https://raw.githubusercontent.com/KieranGliver/mc-server/main/systemd/minecraft.service
systemctl daemon-reload
systemctl enable --now minecraft
