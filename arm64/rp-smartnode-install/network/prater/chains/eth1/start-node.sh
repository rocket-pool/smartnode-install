#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Geth startup
if [ "$CLIENT" = "geth" ]; then

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

    if [ -f "/ethclient/prune.lock" ]; then

        taskset -c $CORE_STRING ionice -c 3 /usr/local/bin/geth snapshot prune-state --goerli --datadir /ethclient/geth --bloomfilter.size 512 ; rm /ethclient/prune.lock

    else 

        # Run Geth with the CPU pinning so it doesn't eat the entire machine, and give it the lowest I/O priority
        CMD="taskset -c $CORE_STRING ionice -c 3 /usr/local/bin/geth --goerli --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,personal,web3 --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,personal,web3"

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

    exec /go/bin/rocketpool-pow-proxy --httpPort 8545 --wsPort 8546 --network goerli --projectId $INFURA_PROJECT_ID --providerType infura

fi


# Pocket startup
if [ "$CLIENT" = "pocket" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort 8545 --network eth-goerli --projectId $POCKET_PROJECT_ID --providerType pocket

fi


# Custom provider startup
if [ "$CLIENT" = "custom" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort 8545 --wsPort 8546 --httpProviderUrl $HTTP_PROVIDER_URL --wsProviderUrl $WS_PROVIDER_URL --providerType=""

fi

