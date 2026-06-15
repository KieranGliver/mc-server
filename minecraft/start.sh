#!/bin/bash

source /opt/minecraft/.config

if [ "$EDITION" = "java" ]; then
	java -Xmx$JAVA_MEMORY -Xms$JAVA_MEMORY -jar server.jar nogui
elif [ "$EDITION" = "bedrock" ]; then
	exec screen -DmS minecraft ./bedrock_server
else
	echo "Unknown edition: $EDITION"
	exit 1
fi
