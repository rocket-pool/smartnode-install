#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Geth startup
if [ "$CLIENT" = "geth" ]; then

    CMD="/usr/local/bin/geth --goerli --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,personal,web3 --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,personal,web3"

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

