#!/bin/bash

# Rocket Pool docker config utility
# Configures Rocket Pool service stack docker options

# Check RP_PATH is set
if [ -z "$RP_PATH" ]; then
    echo "The RP_PATH environment variable is not set. If you've just installed Rocket Pool, please start a new terminal session and try again."
    exit 1
fi

# Get docker .env file path
DOCKERENV="$RP_PATH/docker/.env"

# Write docker config
echo "COMPOSE_PROJECT_NAME=rocketpool" > "$DOCKERENV"
echo "" >> "$DOCKERENV"
echo "POW_CLIENT=geth" >> "$DOCKERENV"
echo "POW_IMAGE=ethereum/client-go:latest" >> "$DOCKERENV"
echo "POW_NETWORK_ID=77" >> "$DOCKERENV"
echo "POW_BOOTNODE=enode://6114b79e7928bfb19ff8600bad6e09a49cfc53f7d9513bb0e854566102ee04bac8f494472bcc812211c2cc50684f8a04320d23c17410b52c6175e8246b5a3307@3.216.221.20:30305,enode://80b8fe6fe4fe82761b2b40d57da58296d82f34f035b182cca411b9e55370f8c4f2734648523261b2be212352f3a218fa61f89517cf6abd005fb9acc27d289ff4@100.27.8.240:30303" >> "$DOCKERENV"
echo "POW_ETHSTATS_LABEL=RP2Beta-Node" >> "$DOCKERENV"
echo "POW_ETHSTATS_LOGIN=rp2testbeta@3.216.221.20" >> "$DOCKERENV"
