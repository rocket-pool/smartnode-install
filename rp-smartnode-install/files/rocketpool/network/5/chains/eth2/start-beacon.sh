#!/bin/sh
# This script configures ETH2 beacon clients for Rocket Pool's scalable docker stack; only edit if you know what you're doing ;)

# Get container ID
CONTAINERID="${HOSTNAME}"

# Create a container data directory if it doesn't exist
DATADIR="/ethclient/$CONTAINERID"
mkdir -p "$DATADIR"

# Lighthouse startup
if [ "$CLIENT" = "Lighthouse" ]; then

    # Run
    CMD="lighthouse beacon --datadir $DATADIR --http --http-address 0.0.0.0 --http-port 5052 --eth1 --eth1-endpoint http://eth1.rpc.smartnode.localhost"

    # Run command
    eval "$CMD"

fi

# Prysm startup
# TODO: implement
