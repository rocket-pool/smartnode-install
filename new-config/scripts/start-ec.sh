#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    $GETH_NETWORK=""
    $INFURA_NETWORK="mainnet"
    $POCKET_NETWORK="eth-mainnet"
elif [ "$NETWORK" = "prater" ]; then
    $GETH_NETWORK="--goerli"
    $INFURA_NETWORK="goerli"
    $POCKET_NETWORK="eth-goerli"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi

# Geth startup
if [ "$CLIENT" = "geth" ]; then

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
        PERF_PREFIX="taskset -c $CORE_STRING ionice -c 3"

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
    fi

    # Check for the prune flag and run that first if requested
    if [ -f "/ethclient/prune.lock" ]; then

        $PERF_PREFIX /usr/local/bin/geth snapshot prune-state $GETH_NETWORK --datadir /ethclient/geth ; rm /ethclient/prune.lock

    # Run Geth normally
    else 

        CMD="$PERF_PREFIX /usr/local/bin/geth $GETH_NETWORK --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port ${EC_HTTP_PORT:-8545} --http.api eth,net,personal,web3 --ws --ws.addr 0.0.0.0 --ws.port ${EC_WS_PORT:-8546} --ws.api eth,net,personal,web3"

        if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
            CMD="$CMD --ethstats $ETHSTATS_LABEL:$ETHSTATS_LOGIN"
        fi

        if [ ! -z "$GETH_CACHE_SIZE" ]; then
            CMD="$CMD --cache $GETH_CACHE_SIZE"
        fi

        if [ ! -z "$GETH_MAX_PEERS" ]; then
            CMD="$CMD --maxpeers $GETH_MAX_PEERS"
        fi

        if [ ! -z "$ETH1_P2P_PORT" ]; then
            CMD="$CMD --port $ETH1_P2P_PORT"
        fi

        exec ${CMD} --http.vhosts '*'

    fi

fi


# Infura startup
if [ "$CLIENT" = "infura" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort ${EC_HTTP_PORT:-8545} --wsPort ${EC_WS_PORT:-8546} --network $INFURA_NETWORK --projectId $INFURA_PROJECT_ID --providerType infura

fi


# Pocket startup
if [ "$CLIENT" = "pocket" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort ${EC_HTTP_PORT:-8545} --network $POCKET_NETWORK --projectId $POCKET_PROJECT_ID --providerType pocket

fi


# Custom provider startup
if [ "$CLIENT" = "custom" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort ${EC_HTTP_PORT:-8545} --wsPort ${EC_WS_PORT:-8546} --httpProviderUrl $HTTP_PROVIDER_URL --wsProviderUrl $WS_PROVIDER_URL --providerType=""

fi

