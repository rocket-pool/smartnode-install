#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Only show client identifier if version string is under 9 characters
version_length=`echo -n $ROCKET_POOL_VERSION | wc -c`
if [ $version_length -lt 9 ]; then
    IDENTIFIER=`echo -n $CLIENT | head -c 1 | tr [a-z] [A-Z] | sed 's/^/-/'`
fi

# Get graffiti text
GRAFFITI="RP$IDENTIFIER $ROCKET_POOL_VERSION"
if [ ! -z "$CUSTOM_GRAFFITI" ]; then
    GRAFFITI="$GRAFFITI ($CUSTOM_GRAFFITI)"
fi

# Performance tuning for ARM systems
UNAME_VAL=$(uname -m)
if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
    PERF_PREFIX="ionice -c 2 -n 0"
fi

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    LH_NETWORK="mainnet"
    NIMBUS_NETWORK="mainnet"
    PRYSM_NETWORK="--mainnet"
    TEKU_NETWORK="mainnet"
    PRYSM_GENESIS_STATE=""
elif [ "$NETWORK" = "prater" ]; then
    LH_NETWORK="prater"
    NIMBUS_NETWORK="prater"
    PRYSM_NETWORK="--prater"
    TEKU_NETWORK="prater"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis.ssz"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then
    
    ETH1_ENDPOINTS="$EC_HTTP_ENDPOINT"

    if [ ! -z "$FALLBACK_EC_HTTP_ENDPOINT" ]; then
        ETH1_ENDPOINTS="$EC_HTTP_ENDPOINT,$FALLBACK_EC_HTTP_ENDPOINT"
    fi

    CMD="$PERF_PREFIX /usr/local/bin/lighthouse beacon --network $LH_NETWORK --datadir /ethclient/lighthouse --port $BN_P2P_PORT --discovery-port $BN_P2P_PORT --eth1 --eth1-endpoints $ETH1_ENDPOINTS --http --http-address 0.0.0.0 --http-port ${BN_API_PORT:-5052} --eth1-blocks-per-log-query 150 --disable-upnp $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --target-peers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics --metrics-address 0.0.0.0 --metrics-port $BN_METRICS_PORT --validator-monitor-auto"
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --checkpoint-sync-url $CHECKPOINT_SYNC_URL"
    fi

    exec ${CMD}

fi


# Nimbus startup
if [ "$CLIENT" = "nimbus" ]; then

    ETH1_WS_PROVIDER_ARG="--web3-url=$EC_WS_ENDPOINT"

    if [ ! -z "$FALLBACK_EC_WS_ENDPOINT" ]; then
        ETH1_WS_PROVIDER_ARG="--web3-url=$EC_WS_ENDPOINT --web3-url=$FALLBACK_EC_WS_ENDPOINT"
    fi

    # Nimbus won't start unless the validator directories already exist
    mkdir -p /validators/nimbus/validators
    mkdir -p /validators/nimbus/secrets

    # Handle checkpoint syncing
    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        # Ignore it if a DB already exists
        if [ -f "/ethclient/nimbus/db/nbc.sqlite3" ]; then 
            echo "Nimbus database already exists, ignoring checkpoint sync."
        else 
            echo "Starting checkpoint sync for Nimbus..."
            $PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_beacon_node trustedNodeSync --network=$NIMBUS_NETWORK --data-dir=/ethclient/nimbus --trusted-node-url=$CHECKPOINT_SYNC_URL --backfill=false
            echo "Checkpoint sync complete!"
        fi
    fi

    CMD="$PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_beacon_node --non-interactive --enr-auto-update --network=$NIMBUS_NETWORK --data-dir=/ethclient/nimbus --tcp-port=$BN_P2P_PORT --udp-port=$BN_P2P_PORT $ETH1_WS_PROVIDER_ARG --rest --rest-address=0.0.0.0 --rest-port=${BN_API_PORT:-5052} --insecure-netkey-password=true --validators-dir=/validators/nimbus/validators --secrets-dir=/validators/nimbus/secrets --num-threads=0 $BN_ADDITIONAL_FLAGS"

    if [ "$DOPPELGANGER_DETECTION" = "false" ]; then
        CMD="$CMD --doppelganger-detection=false"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --max-peers=$BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics --metrics-address=0.0.0.0 --metrics-port=$BN_METRICS_PORT"
    fi

    if [ ! -z "$EXTERNAL_IP" ]; then
        CMD="$CMD --nat=extip:$EXTERNAL_IP"
    fi

    # Graffiti breaks if it's in the CMD string instead of here because of spaces
    exec ${CMD} --graffiti="$GRAFFITI"

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    # Get Prater SSZ if necessary
    if [ "$NETWORK" = "prater" ]; then
        if [ ! -f "/validators/genesis.ssz" ]; then
            wget "https://github.com/eth-clients/eth2-networks/raw/master/shared/prater/genesis.ssz" -O "/validators/genesis.ssz"
        fi
    fi
    
    FALLBACK_PROVIDER=""

    if [ ! -z "$FALLBACK_EC_HTTP_ENDPOINT" ]; then
        FALLBACK_PROVIDER="--fallback-web3provider=$FALLBACK_EC_HTTP_ENDPOINT"
    fi

    CMD="$PERF_PREFIX /app/cmd/beacon-chain/beacon-chain --accept-terms-of-use $PRYSM_NETWORK $PRYSM_GENESIS_STATE --datadir /ethclient/prysm --p2p-tcp-port $BN_P2P_PORT --p2p-udp-port $BN_P2P_PORT --http-web3provider $EC_HTTP_ENDPOINT $FALLBACK_PROVIDER --rpc-host 0.0.0.0 --rpc-port ${BN_RPC_PORT:-5053} --grpc-gateway-host 0.0.0.0 --grpc-gateway-port ${BN_API_PORT:-5052} --eth1-header-req-limit 150 $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --p2p-max-peers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $BN_METRICS_PORT"
    else
        CMD="$CMD --disable-monitoring"
    fi

    exec ${CMD}

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    ETH1_ENDPOINTS="$EC_HTTP_ENDPOINT"

    if [ ! -z "$FALLBACK_EC_HTTP_ENDPOINT" ]; then
        ETH1_ENDPOINTS="$EC_HTTP_ENDPOINT,$FALLBACK_EC_HTTP_ENDPOINT"
    fi

    # Restrict the JVM's heap size to reduce RAM load on ARM systems
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
        export JAVA_OPTS=-Xmx2g
    fi

    CMD="$PERF_PREFIX /opt/teku/bin/teku --network=$TEKU_NETWORK --data-path=/ethclient/teku --p2p-port=$BN_P2P_PORT --eth1-endpoints=$ETH1_ENDPOINTS --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-port=${BN_API_PORT:-5052} --rest-api-host-allowlist=* --eth1-deposit-contract-max-request-size=150 --log-destination=CONSOLE $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --p2p-peer-lower-bound=$BN_MAX_PEERS --p2p-peer-upper-bound=$BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$BN_METRICS_PORT --metrics-host-allowlist=*" 
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --initial-state=$CHECKPOINT_SYNC_URL/eth/v2/debug/beacon/states/finalized"
    fi

    exec ${CMD}

fi
