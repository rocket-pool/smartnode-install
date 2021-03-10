#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Geth startup
if [ "$CLIENT" = "geth" ]; then

    CMD="/usr/local/bin/geth --goerli --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,personal,web3 --http.vhosts '*' --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,personal,web3"

    if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
        CMD="$CMD --ethstats $ETHSTATS_LABEL:$ETHSTATS_LOGIN"
    fi

    exec ${CMD}

fi


# Infura startup
if [ "$CLIENT" = "infura" ]; then

    exec /go/bin/rocketpool-pow-proxy --port 8545 --network goerli --projectId $INFURA_PROJECT_ID

fi


# Custom provider startup
if [ "$CLIENT" = "custom" ]; then

    exec /go/bin/rocketpool-pow-proxy --port 8545 --providerUrl $PROVIDER_URL

fi

