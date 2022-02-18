#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# only show client identifier if version string is under 9 characters
version_length=`echo -n $ROCKET_POOL_VERSION | wc -c`
if [ $version_length -lt 9 ]; then
    IDENTIFIER=`echo -n $CLIENT | head -c 1 | tr [a-z] [A-Z] | sed 's/^/-/'`
fi

# Get graffiti text
GRAFFITI="RP$IDENTIFIER $ROCKET_POOL_VERSION"
if [ ! -z "$CUSTOM_GRAFFITI" ]; then
    GRAFFITI="$GRAFFITI ($CUSTOM_GRAFFITI)"
fi


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    ETH1_ENDPOINTS="$ETH1_PROVIDER"

    if [ ! -z "$ETH1_FALLBACK_PROVIDER" ]; then
        ETH1_ENDPOINTS="$ETH1_PROVIDER,$ETH1_FALLBACK_PROVIDER"
    fi

    # Give Lighthouse access to all cores and maximum I/O priority
    CMD="ionice -c 2 -n 0 /usr/local/bin/lighthouse beacon --network prater --datadir /ethclient/lighthouse --port $ETH2_P2P_PORT --discovery-port $ETH2_P2P_PORT --eth1 --eth1-endpoints $ETH1_ENDPOINTS --http --http-address 0.0.0.0 --http-port 5052 --eth1-blocks-per-log-query 150 --disable-upnp"

    if [ ! -z "$ETH2_MAX_PEERS" ]; then
        CMD="$CMD --target-peers $ETH2_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --metrics --metrics-address 0.0.0.0 --metrics-port $ETH2_METRICS_PORT --validator-monitor-auto"
    fi

    if [ ! -z "$ETH2_CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --checkpoint-sync-url $ETH2_CHECKPOINT_SYNC_URL"
    fi

    exec ${CMD}

fi


# Nimbus startup
if [ "$CLIENT" = "nimbus" ]; then

    ETH1_WS_PROVIDER_ARG="--web3-url=$ETH1_WS_PROVIDER"

    if [ ! -z "$ETH1_FALLBACK_WS_PROVIDER" ]; then
        ETH1_WS_PROVIDER_ARG="--web3-url=$ETH1_WS_PROVIDER --web3-url=$ETH1_FALLBACK_WS_PROVIDER"
    fi

    # Nimbus won't start unless the validator directories already exist
    mkdir -p /validators/nimbus/validators
    mkdir -p /validators/nimbus/secrets

    # Handle checkpoint syncing
    if [ ! -z "$ETH2_CHECKPOINT_SYNC_URL" ]; then
        # Ignore it if a DB already exists
        if [ -f "/ethclient/nimbus/db/nbc.sqlite3" ]; then 
            echo "Nimbus database already exists, ignoring checkpoint sync."
        else 
            echo "Starting checkpoint sync for Nimbus..."
            ionice -c 2 -n 0 /home/user/nimbus-eth2/build/nimbus_beacon_node trustedNodeSync --network=prater --data-dir=/ethclient/nimbus --trusted-node-url=$ETH2_CHECKPOINT_SYNC_URL --backfill=false
            echo "Checkpoint sync complete!"
        fi
    fi

    # Give Nimbus the highest I/O priority
    CMD="ionice -c 2 -n 0 /home/user/nimbus-eth2/build/nimbus_beacon_node --non-interactive --enr-auto-update --network=prater --data-dir=/ethclient/nimbus --tcp-port=$ETH2_P2P_PORT --udp-port=$ETH2_P2P_PORT $ETH1_WS_PROVIDER_ARG --rest --rest-address=0.0.0.0 --rest-port=5052 --insecure-netkey-password=true --validators-dir=/validators/nimbus/validators --secrets-dir=/validators/nimbus/secrets --num-threads=0"

    if [ ! "$ETH2_DOPPELGANGER_DETECTION" = "y" ]; then
        CMD="$CMD --doppelganger-detection=false"
    fi

    if [ ! -z "$ETH2_MAX_PEERS" ]; then
        CMD="$CMD --max-peers=$ETH2_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --metrics --metrics-address=0.0.0.0 --metrics-port=$ETH2_METRICS_PORT"
    fi

    if [ ! -z "$EXTERNAL_IP" ]; then
        CMD="$CMD --nat=extip:$EXTERNAL_IP"
    fi

    # Graffiti breaks if it's in the CMD string instead of here because of spaces
    exec ${CMD} --graffiti="$GRAFFITI"

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    # Get Prater SSZ
    if [ ! -f "/validators/genesis.ssz" ]; then
        wget "https://github.com/eth-clients/eth2-networks/raw/master/shared/prater/genesis.ssz" -O "/validators/genesis.ssz"
    fi

    if [ -z "$ETH2_RPC_PORT" ]; then
        ETH2_RPC_PORT="5053"
    fi

    FALLBACK_PROVIDER=""

    if [ ! -z "$ETH1_FALLBACK_PROVIDER" ]; then
        FALLBACK_PROVIDER="--fallback-web3provider=$ETH1_FALLBACK_PROVIDER"
    fi

    # Give Prysm access to all cores and maximum I/O priority
    CMD="ionice -c 2 -n 0 /app/cmd/beacon-chain/beacon-chain --accept-terms-of-use --prater --genesis-state=/validators/genesis.ssz --datadir /ethclient/prysm --p2p-tcp-port $ETH2_P2P_PORT --p2p-udp-port $ETH2_P2P_PORT --http-web3provider $ETH1_PROVIDER $FALLBACK_PROVIDER --rpc-host 0.0.0.0 --rpc-port $ETH2_RPC_PORT --grpc-gateway-host 0.0.0.0 --grpc-gateway-port 5052 --eth1-header-req-limit 150"

    if [ ! -z "$ETH2_MAX_PEERS" ]; then
        CMD="$CMD --p2p-max-peers $ETH2_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $ETH2_METRICS_PORT"
    else
        CMD="$CMD --disable-monitoring"
    fi

    exec ${CMD}

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    ETH1_ENDPOINTS="$ETH1_PROVIDER"

    if [ ! -z "$ETH1_FALLBACK_PROVIDER" ]; then
        ETH1_ENDPOINTS="$ETH1_PROVIDER,$ETH1_FALLBACK_PROVIDER"
    fi

    # Restrict the JVM's heap size to reduce RAM load
    export JAVA_OPTS=-Xmx3g

    # Give Teku access to all cores and maximum I/O priority
    CMD="ionice -c 2 -n 0 /opt/teku/bin/teku --network=prater --data-path=/ethclient/teku --p2p-port=$ETH2_P2P_PORT --eth1-endpoints=$ETH1_ENDPOINTS --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-port=5052 --rest-api-host-allowlist=* --eth1-deposit-contract-max-request-size=150 --log-destination=CONSOLE"

    if [ ! -z "$ETH2_MAX_PEERS" ]; then
        CMD="$CMD --p2p-peer-lower-bound=$ETH2_MAX_PEERS --p2p-peer-upper-bound=$ETH2_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$ETH2_METRICS_PORT --metrics-host-allowlist=*" 
    fi

    if [ ! -z "$ETH2_CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --initial-state=$ETH2_CHECKPOINT_SYNC_URL/eth/v1/debug/beacon/states/finalized"
    fi

    exec ${CMD}

fi
