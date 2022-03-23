#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    GETH_NETWORK=""
elif [ "$NETWORK" = "prater" ]; then
    GETH_NETWORK="--goerli"
elif [ "$NETWORK" = "kiln" ]; then
    GETH_NETWORK="--networkid=1337802"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi

# Geth startup
if [ "$CLIENT" = "geth" ]; then

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then

        # Install taskset and ionice
        apk add util-linux

        # Get the number of available cores
        CORE_COUNT=$(grep -c ^processor /proc/cpuinfo)

        # Give Geth access to the last core
        CURRENT_CORE=$((CORE_COUNT - 1))
        CORE_STRING="$CURRENT_CORE"

        # If there are more than 2 cores, limit Geth to use all but the first 2
        CURRENT_CORE=$((CURRENT_CORE - 1))
        while [ "$CURRENT_CORE" -gt "1" ]; do
            CORE_STRING="$CORE_STRING,$CURRENT_CORE"
            CURRENT_CORE=$((CURRENT_CORE - 1))
        done
        
        PERF_PREFIX="taskset -c $CORE_STRING ionice -c 3"
    fi

    # Check for the prune flag and run that first if requested
    if [ -f "/ethclient/prune.lock" ]; then

        $PERF_PREFIX /usr/local/bin/geth snapshot prune-state $GETH_NETWORK --datadir /ethclient/geth ; rm /ethclient/prune.lock

    # Run Geth normally
    else 

        CMD="$PERF_PREFIX /usr/local/bin/geth $GETH_NETWORK --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port ${EC_HTTP_PORT:-8545} --http.api eth,net,personal,web3,engine --ws --ws.addr 0.0.0.0 --ws.port ${EC_WS_PORT:-8546} --ws.api eth,net,personal,web3,engine --bootnodes enode://c354db99124f0faf677ff0e75c3cbbd568b2febc186af664e0c51ac435609badedc67a18a63adb64dacc1780a28dcefebfc29b83fd1a3f4aa3c0eb161364cf94@164.92.130.5:30303 --authrpc.jwtsecret /ethclient/geth/jwtsecret --authrpc.addr 0.0.0.0 --authrpc.vhosts=* --override.terminaltotaldifficulty 20000000000000 --syncmode=full $EC_ADDITIONAL_FLAGS"

        if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
            CMD="$CMD --ethstats $ETHSTATS_LABEL:$ETHSTATS_LOGIN"
        fi

        if [ ! -z "$EC_CACHE_SIZE" ]; then
            CMD="$CMD --cache $EC_CACHE_SIZE"
        fi

        if [ ! -z "$EC_MAX_PEERS" ]; then
            CMD="$CMD --maxpeers $EC_MAX_PEERS"
        fi

        if [ ! -z "$EC_P2P_PORT" ]; then
            CMD="$CMD --port $EC_P2P_PORT"
        fi

        exec ${CMD} --http.vhosts '*'

    fi

fi
