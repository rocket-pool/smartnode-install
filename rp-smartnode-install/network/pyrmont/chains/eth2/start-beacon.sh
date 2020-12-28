#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    exec /usr/local/bin/lighthouse beacon --network pyrmont --datadir /ethclient/lighthouse --port 9001 --discovery-port 9001 --eth1 --eth1-endpoint "$ETH1_PROVIDER" --http --http-address 0.0.0.0 --http-port 5052

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    exec /app/beacon-chain/beacon-chain --accept-terms-of-use --pyrmont --datadir /ethclient/prysm --p2p-tcp-port 9001 --p2p-udp-port 9001 --http-web3provider "$ETH1_PROVIDER" --rpc-host 0.0.0.0 --rpc-port 5052

fi

