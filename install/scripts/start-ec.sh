#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Performance tuning for ARM systems
define_perf_prefix() {
    # Get the number of available cores
    CORE_COUNT=$(grep -c ^processor /proc/cpuinfo)

    # Give the EC access to the last core
    CURRENT_CORE=$((CORE_COUNT - 1))
    CORE_STRING="$CURRENT_CORE"

    # If there are more than 2 cores, limit the EC to use all but the first one
    CURRENT_CORE=$((CURRENT_CORE - 1))
    while [ "$CURRENT_CORE" -gt "0" ]; do
        CORE_STRING="$CORE_STRING,$CURRENT_CORE"
        CURRENT_CORE=$((CURRENT_CORE - 1))
    done

    PERF_PREFIX="taskset -c $CORE_STRING ionice -c 3"
}

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    GETH_NETWORK=""
    NETHERMIND_NETWORK="mainnet"
    BESU_NETWORK="mainnet"
    INFURA_NETWORK="mainnet"
    POCKET_NETWORK="eth-mainnet"
elif [ "$NETWORK" = "prater" ]; then
    GETH_NETWORK="--goerli"
    NETHERMIND_NETWORK="goerli"
    BESU_NETWORK="goerli"
    INFURA_NETWORK="goerli"
    POCKET_NETWORK="eth-goerli"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi


# Geth startup
if [ "$CLIENT" = "geth" ]; then

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then

        # Install taskset and ionice
        apk add util-linux

        # Define the performance tuning prefix
        define_perf_prefix

    fi

    # Check for the prune flag and run that first if requested
    if [ -f "/ethclient/prune.lock" ]; then

        $PERF_PREFIX /usr/local/bin/geth snapshot prune-state $GETH_NETWORK --datadir /ethclient/geth ; rm /ethclient/prune.lock

    # Run Geth normally
    else 

        CMD="$PERF_PREFIX /usr/local/bin/geth $GETH_NETWORK --datadir /ethclient/geth --http --http.addr 0.0.0.0 --http.port ${EC_HTTP_PORT:-8545} --http.api eth,net,personal,web3 --ws --ws.addr 0.0.0.0 --ws.port ${EC_WS_PORT:-8546} --ws.api eth,net,personal,web3 $EC_ADDITIONAL_FLAGS"

        if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
            CMD="$CMD --ethstats $ETHSTATS_LABEL:$ETHSTATS_LOGIN"
        fi

        if [ ! -z "$EC_CACHE_SIZE" ]; then
            CMD="$CMD --cache $EC_CACHE_SIZE"
        fi

        if [ ! -z "$EC_MAX_PEERS" ]; then
            CMD="$CMD --maxpeers $EC_MAX_PEERS"
        fi

        if [ "$ENABLE_METRICS" = "true" ]; then
            CMD="$CMD --metrics --metrics.addr 0.0.0.0 --metrics.port $EC_METRICS_PORT"
        fi

        if [ ! -z "$EC_P2P_PORT" ]; then
            CMD="$CMD --port $EC_P2P_PORT"
        fi

        exec ${CMD} --http.vhosts '*'

    fi

fi


# Nethermind startup
if [ "$CLIENT" = "nethermind" ]; then

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then

        # Define the performance tuning prefix
        define_perf_prefix

    fi

    # Check for the prune flag
    if [ -f "/ethclient/prune.lock" ]; then
        NETHERMIND_PRUNE=1
        rm /ethclient/prune.lock
    fi

    # Set the JSON RPC logging level
    LOG_LINE=$(awk '/<logger name=\"\*\" minlevel=\"Off\" writeTo=\"seq\" \/>/{print NR}' /nethermind/NLog.config)
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" final=\"true\"/>\\n" -i /nethermind/NLog.config
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" minlevel=\"Warn\" writeTo=\"auto-colored-console-async\" final=\"true\"/>" -i /nethermind/NLog.config
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" minlevel=\"Warn\" writeTo=\"file-async\" final=\"true\"\/>" -i /nethermind/NLog.config

    # Uncomment peer report logging restrictions in the log config XML
    sed -i 's/<!-- \(<logger name=\"Synchronization\.Peers\.SyncPeersReport\".*\/>\).*-->/\1/g' /nethermind/NLog.config

    CMD="$PERF_PREFIX /nethermind/Nethermind.Runner --config $NETHERMIND_NETWORK --datadir /ethclient/nethermind --JsonRpc.Enabled true --JsonRpc.Host 0.0.0.0 --JsonRpc.Port ${EC_HTTP_PORT:-8545} --JsonRpc.EnabledModules Eth,Net,Personal,Web3  --Init.WebSocketsEnabled true --JsonRpc.WebSocketsPort ${EC_WS_PORT:-8546} --Sync.AncientBodiesBarrier 1 --Sync.AncientReceiptsBarrier 1 --Sync.SnapSync true $EC_ADDITIONAL_FLAGS"

    if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
        CMD="$CMD --EthStats.Enabled true --EthStats.Name $ETHSTATS_LABEL --EthStats.Secret $(echo $ETHSTATS_LOGIN | cut -d "@" -f1) --EthStats.Server $(echo $ETHSTATS_LOGIN | cut -d "@" -f2)"
    fi

    if [ ! -z "$EC_CACHE_SIZE" ]; then
        CMD="$CMD --Init.MemoryHint ${EC_CACHE_SIZE}000000"
    fi

    if [ ! -z "$EC_MAX_PEERS" ]; then
        CMD="$CMD --Network.MaxActivePeers $EC_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --Metrics.Enabled true --Metrics.ExposePort $EC_METRICS_PORT"
    fi

    if [ ! -z "$EC_P2P_PORT" ]; then
        CMD="$CMD --Network.DiscoveryPort $EC_P2P_PORT --Network.P2PPort $EC_P2P_PORT"
    fi

    if [ ! -z "$NETHERMIND_PRUNE" ]; then
        # --Pruning.ShutdownAfterFullPrune true
        CMD="$CMD --Pruning.Mode Full --JsonRpc.AdditionalRpcUrls http://localhost:7434|http|admin"
    else
        CMD="$CMD --Pruning.Mode Memory"
    fi

    if [ ! -z "$NETHERMIND_PRUNE_MEM_SIZE" ]; then
        CMD="$CMD --Pruning.CacheMb $NETHERMIND_PRUNE_MEM_SIZE"
    fi

    exec ${CMD}

fi


# Besu startup
if [ "$CLIENT" = "besu" ]; then

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then

        # Define the performance tuning prefix
        define_perf_prefix

    fi

    CMD="$PERF_PREFIX /opt/besu/bin/besu --network=$BESU_NETWORK --data-path=/ethclient/besu --rpc-http-enabled --rpc-http-host=0.0.0.0 --rpc-http-port=${EC_HTTP_PORT:-8545} --rpc-ws-enabled --rpc-ws-host=0.0.0.0 --rpc-ws-port=${EC_WS_PORT:-8546} --host-allowlist=* --revert-reason-enabled --rpc-http-max-active-connections=65536 --data-storage-format=bonsai --sync-mode=X_SNAP --nat-method=docker --p2p-host=$EXTERNAL_IP $EC_ADDITIONAL_FLAGS"

    if [ ! -z "$ETHSTATS_LABEL" ] && [ ! -z "$ETHSTATS_LOGIN" ]; then
        CMD="$CMD --ethstats $ETHSTATS_LABEL:$ETHSTATS_LOGIN"
    fi

    if [ ! -z "$EC_MAX_PEERS" ]; then
        CMD="$CMD --max-peers=$EC_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-enabled --metrics-host=0.0.0.0 --metrics-port=$EC_METRICS_PORT"
    fi

    if [ ! -z "$EC_P2P_PORT" ]; then
        CMD="$CMD --p2p-port=$EC_P2P_PORT"
    fi

    if [ ! -z "$BESU_MAX_BACK_LAYERS" ]; then
        CMD="$CMD --bonsai-maximum-back-layers-to-load=$BESU_MAX_BACK_LAYERS"
    fi

    if [ "$BESU_JVM_HEAP_SIZE" -gt "0" ]; then
        CMD="env JAVA_OPTS=\"-Xmx${BESU_JVM_HEAP_SIZE}m\" $CMD"
    fi

    exec ${CMD}

fi


# Infura startup
if [ "$CLIENT" = "infura" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort ${EC_HTTP_PORT:-8545} --wsPort ${EC_WS_PORT:-8546} --network $INFURA_NETWORK --projectId $INFURA_PROJECT_ID --providerType infura $EC_ADDITIONAL_FLAGS

fi


# Pocket startup
if [ "$CLIENT" = "pocket" ]; then

    exec /go/bin/rocketpool-pow-proxy --httpPort ${EC_HTTP_PORT:-8545} --network $POCKET_NETWORK --projectId $POCKET_GATEWAY_ID --providerType pocket $EC_ADDITIONAL_FLAGS

fi

