#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Performance tuning for ARM systems
UNAME_VAL=$(uname -m)
if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
    PERF_PREFIX="ionice -c 2 -n 0"
fi

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    LH_NETWORK="mainnet"
    LODESTAR_NETWORK="mainnet"
    NIMBUS_NETWORK="mainnet"
    PRYSM_NETWORK="--mainnet"
    TEKU_NETWORK="mainnet"
    PRYSM_GENESIS_STATE=""
elif [ "$NETWORK" = "prater" ]; then
    LH_NETWORK="prater"
    LODESTAR_NETWORK="prater"
    NIMBUS_NETWORK="prater"
    PRYSM_NETWORK="--prater"
    TEKU_NETWORK="prater"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-prater.ssz"
elif [ "$NETWORK" = "kiln" ]; then
    LH_NETWORK="kiln"
    LODESTAR_NETWORK="kiln"
    NIMBUS_NETWORK=""
    PRYSM_NETWORK=""
    TEKU_NETWORK="kiln"
elif [ "$NETWORK" = "ropsten" ]; then
    LH_NETWORK="ropsten"
    LODESTAR_NETWORK="ropsten"
    NIMBUS_NETWORK="ropsten"
    PRYSM_NETWORK="--ropsten"
    TEKU_NETWORK="ropsten"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-ropsten.ssz"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi

# Check for the JWT auth file
if [ ! -f "/secrets/jwtsecret" ]; then
    echo "JWT secret file not found, please try again when the Execution Client has created one."
    exit 1
fi

# Report a missing fee recipient file
if [ ! -f "/validators/$FEE_RECIPIENT_FILE" ]; then
    echo "Fee recipient file not found, please wait for the rocketpool_node process to create one."
    exit 1
fi

# Lighthouse startup
if [ "$CC_CLIENT" = "lighthouse" ]; then

    CMD="$PERF_PREFIX /usr/local/bin/lighthouse beacon --network $LH_NETWORK --datadir /ethclient/lighthouse --port $BN_P2P_PORT --discovery-port $BN_P2P_PORT --execution-endpoint $EC_ENGINE_ENDPOINT --http --http-address 0.0.0.0 --http-port ${BN_API_PORT:-5052} --eth1-blocks-per-log-query 150 --disable-upnp --staking --http-allow-sync-stalled --execution-jwt=/secrets/jwtsecret $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$TTD_OVERRIDE" ]; then
        CMD="$CMD --terminal-total-difficulty-override=$TTD_OVERRIDE"
    fi

    if [ ! -z "$MEV_BOOST_URL" ]; then
        CMD="$CMD --builder $MEV_BOOST_URL"
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

# Lodestar startup
if [ "$CC_CLIENT" = "lodestar" ]; then

    CMD="$PERF_PREFIX /usr/app/node_modules/.bin/lodestar beacon --network $LODESTAR_NETWORK --rootDir /ethclient/lodestar --port $BN_P2P_PORT --execution.urls $EC_ENGINE_ENDPOINT --api.rest.enabled --api.rest.address 0.0.0.0 --api.rest.port ${BN_API_PORT:-5052} --jwt-secret /secrets/jwtsecret $BN_ADDITIONAL_FLAGS"

    if [ "$NETWORK" = "mainnet" ]; then
        CMD="$CMD --terminal-total-difficulty-override=115792089237316195423570985008687907853269984665640564039457584007913129638912"
    fi

    if [ "$NETWORK" = "ropsten" -o "$NETWORK" = "kiln" -o "$NETWORK" = "prater" ]; then
        CMD="$CMD --builder.enabled --builder.urls $MEV_BOOST_URL"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --network.targetPeers $BN_MAX_PEERS --network.maxPeers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics.enabled --metrics.address 0.0.0.0 --metrics.port $BN_METRICS_PORT"
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --weakSubjectivityServerUrl $CHECKPOINT_SYNC_URL --weakSubjectivitySyncLatest"
    fi

    exec ${CMD}

fi

# Nimbus startup
if [ "$CC_CLIENT" = "nimbus" ]; then

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

    CMD="$PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_beacon_node --non-interactive --enr-auto-update --network=$NIMBUS_NETWORK --data-dir=/ethclient/nimbus --tcp-port=$BN_P2P_PORT --udp-port=$BN_P2P_PORT --web3-url=$EC_ENGINE_ENDPOINT --rest --rest-address=0.0.0.0 --rest-port=${BN_API_PORT:-5052} --insecure-netkey-password=true --validators-dir=/validators/nimbus/validators --secrets-dir=/validators/nimbus/secrets --doppelganger-detection=$DOPPELGANGER_DETECTION --jwt-secret=/secrets/jwtsecret --suggested-fee-recipient=$(cat /validators/$FEE_RECIPIENT_FILE) $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$TTD_OVERRIDE" ]; then
        CMD="$CMD --terminal-total-difficulty-override=$TTD_OVERRIDE"
    fi

    if [ ! -z "$MEV_BOOST_URL" ]; then
        CMD="$CMD --payload-builder --payload-builder-url=$MEV_BOOST_URL"
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

    CMD="$PERF_PREFIX /app/cmd/beacon-chain/beacon-chain --accept-terms-of-use $PRYSM_NETWORK $PRYSM_GENESIS_STATE --datadir /ethclient/prysm --p2p-tcp-port $BN_P2P_PORT --p2p-udp-port $BN_P2P_PORT --execution-endpoint $EC_ENGINE_ENDPOINT --rpc-host 0.0.0.0 --rpc-port ${BN_RPC_PORT:-5053} --grpc-gateway-host 0.0.0.0 --grpc-gateway-port ${BN_API_PORT:-5052} --eth1-header-req-limit 150 --jwt-secret=/secrets/jwtsecret --api-timeout 600 $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$TTD_OVERRIDE" ]; then
        CMD="$CMD --terminal-total-difficulty-override=$TTD_OVERRIDE"
    fi

    if [ ! -z "$MEV_BOOST_URL" ]; then
        CMD="$CMD --http-mev-relay $MEV_BOOST_URL"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --p2p-max-peers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $BN_METRICS_PORT"
    else
        CMD="$CMD --disable-monitoring"
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --checkpoint-sync-url=$CHECKPOINT_SYNC_URL --genesis-beacon-api-url=$CHECKPOINT_SYNC_URL"
    fi

    exec ${CMD}

fi

# Teku startup
if [ "$CC_CLIENT" = "teku" ]; then

    CMD="$PERF_PREFIX /opt/teku/bin/teku --network=$TEKU_NETWORK --data-path=/ethclient/teku --p2p-port=$BN_P2P_PORT --ee-endpoint=$EC_ENGINE_ENDPOINT --rest-api-enabled --rest-api-interface=0.0.0.0 --rest-api-port=${BN_API_PORT:-5052} --rest-api-host-allowlist=* --data-storage-mode=archive --eth1-deposit-contract-max-request-size=150 --log-destination=CONSOLE --ee-jwt-secret-file=/secrets/jwtsecret --validators-proposer-default-fee-recipient=$RETH_ADDRESS $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$TTD_OVERRIDE" ]; then
        CMD="$CMD --Xnetwork-total-terminal-difficulty-override=$TTD_OVERRIDE"
    fi

    if [ ! -z "$MEV_BOOST_URL" ]; then
        CMD="$CMD --builder-endpoint=$MEV_BOOST_URL"
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
