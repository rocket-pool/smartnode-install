#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Only show client identifier if version string is under 9 characters
version_length=`echo -n $ROCKET_POOL_VERSION | wc -c`
if [ $version_length -lt 8 ]; then
    EC_INITIAL=`echo -n $EC_CLIENT | head -c 1 | tr [a-z] [A-Z]`
    CC_INITIAL=`echo -n $CC_CLIENT | head -c 1 | tr [a-z] [A-Z]`
    IDENTIFIER="-${EC_INITIAL}${CC_INITIAL}"
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
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-prater.ssz"
elif [ "$NETWORK" = "kiln" ]; then
    LH_NETWORK="kiln"
    NIMBUS_NETWORK=""
    PRYSM_NETWORK=""
    TEKU_NETWORK="kiln"
elif [ "$NETWORK" = "ropsten" ]; then
    LH_NETWORK="ropsten"
    NIMBUS_NETWORK="ropsten"
    PRYSM_NETWORK="--ropsten"
    TEKU_NETWORK="ropsten"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-ropsten.ssz"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi


# Lighthouse startup
if [ "$CC_CLIENT" = "lighthouse" ]; then

    CMD="$PERF_PREFIX /usr/local/bin/lighthouse beacon --network $LH_NETWORK --datadir /ethclient/lighthouse --port $BN_P2P_PORT --discovery-port $BN_P2P_PORT --eth1 --eth1-endpoints $EC_HTTP_ENDPOINT --execution-endpoints $EC_ENGINE_ENDPOINT --http --http-address 0.0.0.0 --http-port ${BN_API_PORT:-5052} --eth1-blocks-per-log-query 150 --disable-upnp --staking --http-allow-sync-stalled --merge --jwt-secrets=/secrets/jwtsecret $BN_ADDITIONAL_FLAGS"

    if [ "$NETWORK" = "kiln" ]; then
        CMD="$CMD --terminal-total-difficulty-override=20000000000000 --boot-nodes=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk"
    elif [ "$NETWORK" = "ropsten" ]; then
        CMD="$CMD --terminal-total-difficulty-override=50000000000000000"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --target-peers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics --metrics-address 0.0.0.0 --metrics-port $BN_METRICS_PORT --validator-monitor-auto"
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --checkpoint-sync-url $CHECKPOINT_SYNC_URL"
    fi
    
    if [ "$ENABLE_BITFLY_NODE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-endpoint $BITFLY_NODE_METRICS_ENDPOINT?apikey=$BITFLY_NODE_METRICS_SECRET&machine=$BITFLY_NODE_METRICS_MACHINE_NAME"
    fi

    exec ${CMD}

fi


# Nimbus startup
if [ "$CC_CLIENT" = "nimbus" ]; then

    # Nimbus won't start unless the validator directories already exist
    mkdir -p /validators/nimbus/validators
    mkdir -p /validators/nimbus/secrets

    # Copy the default fee recipient file from the template
    if [ ! -f "/validators/nimbus/$FEE_RECIPIENT_FILE" ]; then
        cp "/fr-default/nimbus" "/validators/nimbus/$FEE_RECIPIENT_FILE"
    fi

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

    CMD="$PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_beacon_node --non-interactive --enr-auto-update --network=$NIMBUS_NETWORK --data-dir=/ethclient/nimbus --tcp-port=$BN_P2P_PORT --udp-port=$BN_P2P_PORT --web3-url=$EC_ENGINE_ENDPOINT --rest --rest-address=0.0.0.0 --rest-port=${BN_API_PORT:-5052} --insecure-netkey-password=true --validators-dir=/validators/nimbus/validators --secrets-dir=/validators/nimbus/secrets --doppelganger-detection=$DOPPELGANGER_DETECTION --jwt-secret=/secrets/jwtsecret --suggested-fee-recipient=$(cat /validators/nimbus/$FEE_RECIPIENT_FILE) $BN_ADDITIONAL_FLAGS"

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
if [ "$CC_CLIENT" = "prysm" ]; then

    # Get Prater SSZ if necessary
    if [ "$NETWORK" = "prater" ]; then
        if [ ! -f "/validators/genesis-prater.ssz" ]; then
            wget "https://github.com/eth-clients/eth2-networks/raw/master/shared/prater/genesis.ssz" -O "/validators/genesis-prater.ssz"
        fi
    elif [ "$NETWORK" = "ropsten" ]; then
        if [ ! -f "/validators/genesis-ropsten.ssz" ]; then
            wget "https://github.com/eth-clients/merge-testnets/raw/main/ropsten-beacon-chain/genesis.ssz" -O "/validators/genesis-ropsten.ssz"
        fi
    fi

    FALLBACK_PROVIDER=""

    if [ ! -z "$FALLBACK_EC_HTTP_ENDPOINT" ]; then
        FALLBACK_PROVIDER="--fallback-web3provider=$FALLBACK_EC_HTTP_ENDPOINT"
    fi

    CMD="$PERF_PREFIX /app/cmd/beacon-chain/beacon-chain --accept-terms-of-use $PRYSM_NETWORK $PRYSM_GENESIS_STATE --datadir /ethclient/prysm --p2p-tcp-port $BN_P2P_PORT --p2p-udp-port $BN_P2P_PORT --http-web3provider $EC_ENGINE_ENDPOINT --rpc-host 0.0.0.0 --rpc-port ${BN_RPC_PORT:-5053} --grpc-gateway-host 0.0.0.0 --grpc-gateway-port ${BN_API_PORT:-5052} --eth1-header-req-limit 150 --jwt-secret=/secrets/jwtsecret $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --p2p-max-peers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $BN_METRICS_PORT"
    else
        CMD="$CMD --disable-monitoring"
    fi
    
    # if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
    #    CMD="$CMD --checkpoint-sync-url=$CHECKPOINT_SYNC_URL --genesis-beacon-api-url=$CHECKPOINT_SYNC_URL"
    # fi

    exec ${CMD}

fi


# Teku startup
if [ "$CC_CLIENT" = "teku" ]; then

    CMD="$PERF_PREFIX /opt/teku/bin/teku --network=$TEKU_NETWORK --data-path=/ethclient/teku --p2p-port=$BN_P2P_PORT --ee-endpoint=$EC_ENGINE_ENDPOINT --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-port=${BN_API_PORT:-5052} --rest-api-host-allowlist=* --eth1-deposit-contract-max-request-size=150 --log-destination=CONSOLE --ee-jwt-secret-file=/secrets/jwtsecret $BN_ADDITIONAL_FLAGS"

    if [ "$NETWORK" = "ropsten" ]; then
        CMD="$CMD --Xnetwork-total-terminal-difficulty-override=50000000000000000"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --p2p-peer-lower-bound=$BN_MAX_PEERS --p2p-peer-upper-bound=$BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$BN_METRICS_PORT --metrics-host-allowlist=*" 
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --initial-state=$CHECKPOINT_SYNC_URL/eth/v2/debug/beacon/states/finalized"
    fi

    if [ "$ENABLE_BITFLY_NODE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-publish-endpoint=$BITFLY_NODE_METRICS_ENDPOINT?apikey=$BITFLY_NODE_METRICS_SECRET&machine=$BITFLY_NODE_METRICS_MACHINE_NAME"
    fi

    if [ "$TEKU_JVM_HEAP_SIZE" -gt "0" ]; then
        CMD="env JAVA_OPTS=\"-Xmx${TEKU_JVM_HEAP_SIZE}m\" $CMD"
    fi

    exec ${CMD}

fi
