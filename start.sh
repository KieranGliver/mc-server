#!/bin/bash

source /opt/minecraft/.config

if [ "$EDITION" = "java" ]; then
	java -Xmx2G -Xms2G -jar server.jar nogui
elif [ "$EDITION" = "bedrock" ]; then
	./bedrock_server
else
	echo "Unknown edition: $EDITION"
	exit 1
fi
