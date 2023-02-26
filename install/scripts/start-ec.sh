#!/bin/sh
# This script launches ETH1 clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Performance tuning for ARM systems
define_perf_prefix() {
    # Get the number of available cores
    CORE_COUNT=$(nproc)

    # Don't do performance tweaks on systems with 6+ cores
    if [ "$CORE_COUNT" -gt "5" ]; then
        echo "$CORE_COUNT cores detected, skipping performance tuning"
        return 0
    else
        echo "$CORE_COUNT cores detected, activating performance tuning"
    fi

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
    echo "Performance tuning: $PERF_PREFIX"
}

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    GETH_NETWORK=""
    RP_NETHERMIND_NETWORK="mainnet"
    BESU_NETWORK="--network=mainnet"
elif [ "$NETWORK" = "prater" ]; then
    GETH_NETWORK="--goerli"
    RP_NETHERMIND_NETWORK="goerli"
    BESU_NETWORK="--network=goerli"
elif [ "$NETWORK" = "devnet" ]; then
    GETH_NETWORK="--goerli"
    RP_NETHERMIND_NETWORK="goerli"
    BESU_NETWORK="--network=goerli"
elif [ "$NETWORK" = "zhejiang" ]; then
    GETH_NETWORK="--networkid=1337803"
    RP_NETHERMIND_NETWORK="/zhejiang/nethermind.json"
    BESU_NETWORK="--network-id=1337803"
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

    # Use Pebble if requested
    if [ "$GETH_USE_PEBBLE" = "true" ]; then
        DB_ENGINE="--db.engine=pebble"
    fi

    # Init the zhejiang data if necessary
    if [ "$NETWORK" = "zhejiang" ]; then
        if [ ! -f "/ethclient/zhejiang.init" ]; then
            $PERF_PREFIX /usr/local/bin/geth $DB_ENGINE --datadir /ethclient/geth init /zhejiang/genesis.json
            touch /ethclient/zhejiang.init
        fi
    fi

    # Check for the prune flag and run that first if requested
    if [ -f "/ethclient/prune.lock" ]; then

        $PERF_PREFIX /usr/local/bin/geth $DB_ENGINE snapshot prune-state $GETH_NETWORK --datadir /ethclient/geth ; rm /ethclient/prune.lock

    # Run Geth normally
    else

        CMD="$PERF_PREFIX /usr/local/bin/geth $GETH_NETWORK \
            ${DB_ENGINE} \
            --datadir /ethclient/geth \
            --http \
            --http.addr 0.0.0.0 \
            --http.port ${EC_HTTP_PORT:-8545} \
            --http.api eth,net,web3 \
            --http.corsdomain=* \
            --ws \
            --ws.addr 0.0.0.0 \
            --ws.port ${EC_WS_PORT:-8546} \
            --ws.api eth,net,web3 \
            --authrpc.addr 0.0.0.0 \
            --authrpc.port ${EC_ENGINE_PORT:-8551} \
            --authrpc.jwtsecret /secrets/jwtsecret \
            --authrpc.vhosts=* \
            --pprof \
            $EC_ADDITIONAL_FLAGS"

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

        if [ "$NETWORK" = "zhejiang" ]; then
            CMD="$CMD --syncmode=full --bootnodes enode://691c66d0ce351633b2ef8b4e4ef7db9966915ca0937415bd2b408df22923f274873b4d4438929e029a13a680140223dcf701cabe22df7d8870044321022dfefa@64.225.78.1:30303,enode://89347b9461727ee1849256d78e84d5c86cc3b4c6c5347650093982b726d71f3d08027e280b399b7b6604ceeda863283dcfe1a01e93728b4883114e9f8c7cc8ef@146.190.238.212:30303,enode://c2892072efe247f21ed7ebea6637ade38512a0ae7c5cffa1bf0786d5e3be1e7f40ff71252a21b36aa9de54e49edbcfc6962a98032adadfa29c8524262e484ad3@165.232.84.160:30303,enode://71e862580d3177a99e9837bd9e9c13c83bde63d3dba1d5cea18e89eb2a17786bbd47a8e7ae690e4d29763b55c205af13965efcaf6105d58e118a5a8ed2b0f6d0@68.183.13.170:30303,enode://2f6cf7f774e4507e7c1b70815f9c0ccd6515ee1170c991ce3137002c6ba9c671af38920f5b8ab8a215b62b3b50388030548f1d826cb6c2b30c0f59472804a045@161.35.147.98:30303"
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

    # Create the JWT secret
    if [ ! -f "/secrets/jwtsecret" ]; then
        openssl rand -hex 32 | tr -d "\n" > /secrets/jwtsecret
    fi

    # Check for the prune flag
    if [ -f "/ethclient/prune.lock" ]; then
        RP_NETHERMIND_PRUNE=1
        rm /ethclient/prune.lock
    fi

    # Set the JSON RPC logging level
    LOG_LINE=$(awk '/<logger name=\"\*\" minlevel=\"Off\" writeTo=\"seq\" \/>/{print NR}' /nethermind/NLog.config)
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" final=\"true\"/>\\n" -i /nethermind/NLog.config
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" minlevel=\"Warn\" writeTo=\"auto-colored-console-async\" final=\"true\"/>" -i /nethermind/NLog.config
    sed -e "${LOG_LINE} i \    <logger name=\"JsonRpc\.\*\" minlevel=\"Warn\" writeTo=\"file-async\" final=\"true\"/>" -i /nethermind/NLog.config

    # Remove the sync peers report but leave error messages
    sed -e "${LOG_LINE} i \    <logger name=\"Synchronization.Peers.SyncPeersReport\" maxlevel=\"Info\" final=\"true\"/>" -i /nethermind/NLog.config
    sed -i 's/<!-- \(<logger name=\"Synchronization\.Peers\.SyncPeersReport\".*\/>\).*-->/\1/g' /nethermind/NLog.config

    CMD="$PERF_PREFIX /nethermind/Nethermind.Runner \
        --config $RP_NETHERMIND_NETWORK \
        --datadir /ethclient/nethermind \
        --JsonRpc.Enabled true \
        --JsonRpc.Host 0.0.0.0 \
        --JsonRpc.Port ${EC_HTTP_PORT:-8545} \
        --JsonRpc.EnginePort ${EC_ENGINE_PORT:-8551} \
        --JsonRpc.EngineHost 0.0.0.0 \
        --Sync.AncientBodiesBarrier 1 \
        --Sync.AncientReceiptsBarrier 1 \
        --Merge.Enabled true \
        --JsonRpc.JwtSecretFile=/secrets/jwtsecret \
        $EC_ADDITIONAL_FLAGS"

    # Add optional supplemental primary JSON-RPC modules
    if [ ! -z "$RP_NETHERMIND_ADDITIONAL_MODULES" ]; then
        RP_NETHERMIND_ADDITIONAL_MODULES=",${RP_NETHERMIND_ADDITIONAL_MODULES}"
    fi
    CMD="$CMD --JsonRpc.EnabledModules Eth,Net,Web3$RP_NETHERMIND_ADDITIONAL_MODULES"

    # Add optional supplemental JSON-RPC URLs
    if [ ! -z "$RP_NETHERMIND_ADDITIONAL_URLS" ]; then
        RP_NETHERMIND_ADDITIONAL_URLS=",${RP_NETHERMIND_ADDITIONAL_URLS}"
    fi
    CMD="$CMD --JsonRpc.AdditionalRpcUrls [\"http://127.0.0.1:7434|http|admin\"$RP_NETHERMIND_ADDITIONAL_URLS]"

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
        if [ "$NETWORK" == "prater" ]; then
            CMD="$CMD --Metrics.PushGatewayUrl=\"\""
        fi
    fi

    if [ ! -z "$EC_P2P_PORT" ]; then
        CMD="$CMD --Network.DiscoveryPort $EC_P2P_PORT --Network.P2PPort $EC_P2P_PORT"
    fi

    if [ ! -z "$RP_NETHERMIND_PRUNE" ]; then
        CMD="$CMD --Pruning.Mode Full --Pruning.FullPruningCompletionBehavior AlwaysShutdown"
    else
        CMD="$CMD --Pruning.Mode Memory"
    fi

    if [ ! -z "$RP_NETHERMIND_PRUNE_MEM_SIZE" ]; then
        CMD="$CMD --Pruning.CacheMb $RP_NETHERMIND_PRUNE_MEM_SIZE"
    fi

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --Sync.SnapSync false"
    else
        CMD="$CMD --Sync.SnapSync true"
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

    # Create the JWT secret
    if [ ! -f "/secrets/jwtsecret" ]; then
        openssl rand -hex 32 | tr -d "\n" > /secrets/jwtsecret
    fi

    CMD="$PERF_PREFIX /opt/besu/bin/besu \
        $BESU_NETWORK \
        --data-path=/ethclient/besu \
        --rpc-http-enabled \
        --rpc-http-host=0.0.0.0 \
        --rpc-http-port=${EC_HTTP_PORT:-8545} \
        --rpc-ws-enabled \
        --rpc-ws-host=0.0.0.0 \
        --rpc-ws-port=${EC_WS_PORT:-8546} \
        --host-allowlist=* \
        --rpc-http-max-active-connections=1024 \
        --data-storage-format=bonsai \
        --nat-method=docker \
        --p2p-host=$EXTERNAL_IP \
        --engine-rpc-enabled \
        --engine-rpc-port=${EC_ENGINE_PORT:-8551} \
        --engine-host-allowlist=* \
        --engine-jwt-secret=/secrets/jwtsecret \
        $EC_ADDITIONAL_FLAGS"

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

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --genesis-file=/zhejiang/besu.json --bootnodes=enode://691c66d0ce351633b2ef8b4e4ef7db9966915ca0937415bd2b408df22923f274873b4d4438929e029a13a680140223dcf701cabe22df7d8870044321022dfefa@64.225.78.1:30303,enode://89347b9461727ee1849256d78e84d5c86cc3b4c6c5347650093982b726d71f3d08027e280b399b7b6604ceeda863283dcfe1a01e93728b4883114e9f8c7cc8ef@146.190.238.212:30303,enode://c2892072efe247f21ed7ebea6637ade38512a0ae7c5cffa1bf0786d5e3be1e7f40ff71252a21b36aa9de54e49edbcfc6962a98032adadfa29c8524262e484ad3@165.232.84.160:30303,enode://71e862580d3177a99e9837bd9e9c13c83bde63d3dba1d5cea18e89eb2a17786bbd47a8e7ae690e4d29763b55c205af13965efcaf6105d58e118a5a8ed2b0f6d0@68.183.13.170:30303,enode://2f6cf7f774e4507e7c1b70815f9c0ccd6515ee1170c991ce3137002c6ba9c671af38920f5b8ab8a215b62b3b50388030548f1d826cb6c2b30c0f59472804a045@161.35.147.98:30303"
    else
        CMD="$CMD --fast-sync-min-peers=3 --sync-mode=X_CHECKPOINT"
    fi

    if [ "$BESU_JVM_HEAP_SIZE" -gt "0" ]; then
        CMD="env JAVA_OPTS=\"-Xmx${BESU_JVM_HEAP_SIZE}m\" $CMD"
    fi

    exec ${CMD}

fi
