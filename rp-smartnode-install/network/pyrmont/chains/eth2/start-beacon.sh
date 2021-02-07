#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    /usr/local/bin/lighthouse beacon --network pyrmont --datadir /ethclient/lighthouse --port 9001 --discovery-port 9001 --eth1 --eth1-endpoint "$ETH1_PROVIDER" --http --http-address 0.0.0.0 --http-port 5052

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    /app/beacon-chain/beacon-chain --accept-terms-of-use --pyrmont --datadir /ethclient/prysm --p2p-tcp-port 9001 --p2p-udp-port 9001 --http-web3provider "$ETH1_PROVIDER" --rpc-host 0.0.0.0 --rpc-port 5052

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    exec /opt/teku/bin/teku --network=pyrmont --data-path=/ethclient/teku --p2p-port=9001 --eth1-endpoint="$ETH1_PROVIDER" --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-port=5052 --rest-api-host-allowlist='*'

fi


# Nimbus startup
if [ "$CLIENT" = "nimbus" ]; then

    # Nimbus won't start unless the validator directories already exist
    mkdir -p /data/validators/nimbus/validators
    mkdir -p /data/validators/nimbus/secrets

    exec /home/user/nimbus-eth2/build/nimbus_beacon_node --non-interactive --network=pyrmont --data-dir=/ethclient/nimbus --log-file="/ethclient/nimbus/nbc_bn_$(date +"%Y%m%d%H%M%S").log" --web3-url="$ETH1_WS_PROVIDER" --tcp-port=9001 --udp-port=9001 --rpc --rpc-port=5052 --rpc-address=0.0.0.0 --insecure-netkey-password=true --validators-dir=/data/validators/nimbus/validators --secrets-dir=/data/validators/nimbus/secrets --graffiti="$GRAFFITI"

fi
