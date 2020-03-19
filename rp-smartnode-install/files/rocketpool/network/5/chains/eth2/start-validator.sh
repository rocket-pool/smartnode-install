#!/bin/sh
# This script configures ETH2 validator clients for Rocket Pool's scalable docker stack; only edit if you know what you're doing ;)

# Lighthouse startup
if [ "$CLIENT" = "Lighthouse" ]; then

    # Run
    CMD="lighthouse validator --datadir /.rocketpool/data/validators --server http://eth2.api.smartnode.localhost"

    # Run command
    eval "$CMD"

fi

# Prysm startup
# TODO: implement
