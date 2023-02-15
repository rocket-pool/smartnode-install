#!/bin/sh
# This script launches ETH2 beacon clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Performance tuning for ARM systems
UNAME_VAL=$(uname -m)
if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
    # Get the number of available cores
    CORE_COUNT=$(nproc)

    # Don't do performance tweaks on systems with 6+ cores
    if [ "$CORE_COUNT" -gt "5" ]; then
        echo "$CORE_COUNT cores detected, skipping performance tuning"
    else
        echo "$CORE_COUNT cores detected, activating performance tuning"
        PERF_PREFIX="ionice -c 2 -n 0"
        echo "Performance tuning: $PERF_PREFIX"
    fi
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
    LODESTAR_NETWORK="goerli"
    NIMBUS_NETWORK="prater"
    PRYSM_NETWORK="--prater"
    TEKU_NETWORK="prater"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-prater.ssz"
elif [ "$NETWORK" = "devnet" ]; then
    LH_NETWORK="prater"
    LODESTAR_NETWORK="goerli"
    NIMBUS_NETWORK="prater"
    PRYSM_NETWORK="--prater"
    TEKU_NETWORK="prater"
    PRYSM_GENESIS_STATE="--genesis-state=/validators/genesis-prater.ssz"
elif [ "$NETWORK" = "zhejiang" ]; then
    LH_NETWORK=""
    LODESTAR_NETWORK=""
    NIMBUS_NETWORK="/zhejiang"
    PRYSM_NETWORK="--chain-config-file=/zhejiang/config.yaml"
    TEKU_NETWORK="/zhejiang/config.yaml"
    PRYSM_GENESIS_STATE="--genesis-state=/zhejiang/genesis.ssz"
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

    if [ "$NETWORK" = "zhejiang" ]; then
        LH_NETWORK_ARG="--testnet-dir=/zhejiang"
    else
        LH_NETWORK_ARG="--network $LH_NETWORK"
    fi

    CMD="$PERF_PREFIX /usr/local/bin/lighthouse beacon \
        $LH_NETWORK_ARG \
        --datadir /ethclient/lighthouse \
        --port $BN_P2P_PORT \
        --discovery-port $BN_P2P_PORT \
        --execution-endpoint $EC_ENGINE_ENDPOINT \
        --http \
        --http-address 0.0.0.0 \
        --http-port ${BN_API_PORT:-5052} \
        --eth1-blocks-per-log-query 150 \
        --disable-upnp \
        --staking \
        --http-allow-sync-stalled \
        --execution-jwt=/secrets/jwtsecret \
        $BN_ADDITIONAL_FLAGS"

    # Performance tuning for ARM systems
    UNAME_VAL=$(uname -m)
    if [ "$UNAME_VAL" = "arm64" ] || [ "$UNAME_VAL" = "aarch64" ]; then
        CMD="$CMD --execution-timeout-multiplier 2 --disable-lock-timeouts"
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

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --boot-nodes=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk,enr:-Ly4QOS00hvPDddEcCpwA1cMykWNdJUK50AjbRgbLZ9FLPyBa78i0NwsQZLSV67elpJU71L1Pt9yqVmE1C6XeSI-LV8Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhEDhTgGJc2VjcDI1NmsxoQIgMUMFvJGlr8dI1TEQy-K78u2TJE2rWvah9nGqLQCEGohzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MK4QMlRAwM7E8YBo6fqP7M2IWrjFHP35uC4pWIttUioZWOiaTl5zgZF2OwSxswTQwpiVCnj4n56bhy4NJVHSe682VWGAYYDHkp4h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhJK-7tSJc2VjcDI1NmsxoQLDq7LlsXIXAoJXPt7rqf6CES1Q40xPw2yW0RQ-Ly5S1YhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MS4QCgiQisRxtzXKlBqq_LN1CRUSGIpDKO4e2hLQsffp0BrC3A7-8F6kxHYtATnzcrsVOr8gnwmBnHYTFvE9UmT-0EHh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhKXoVKCJc2VjcDI1NmsxoQK6J-uvOXMf44iIlilx1uPWGRrrTntjLEFR2u-lHcHofIhzeW5jbmV0c4gAAAAAAAAAAIN0Y3CCIyiDdWRwgiMo,enr:-LK4QOQd-elgl_-dcSoUyHDbxBFNgQ687lzcKJiSBtpCyPQ0DinWSd2PKdJ4FHMkVLWD-oOquXPKSMtyoKpI0-Wo_38Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhES3DaqJc2VjcDI1NmsxoQNIf37JZx-Lc8pnfDwURcHUqLbIEZ1RoxjZuBRtEODseYN0Y3CCIyiDdWRwgiMo,enr:-KG4QLNORYXUK76RPDI4rIVAqX__zSkc5AqMcwAketVzN9YNE8FHSu1im3qJTIeuwqI5JN5SPVsiX7L9nWXgWLRUf6sDhGV0aDKQ7ijXswAAAHJGBQAAAAAAAIJpZIJ2NIJpcIShI5NiiXNlY3AyNTZrMaECpA_KefrVAueFWiLLDZKQPPVOxMuxGogPrI474FaS-x2DdGNwgiMog3VkcIIjKA"
    fi

    exec ${CMD}

fi

# Lodestar startup
if [ "$CC_CLIENT" = "lodestar" ]; then

    if [ "$NETWORK" = "zhejiang" ]; then
        LODESTAR_NETWORK_ARG="--paramsFile=/zhejiang/config.yaml --genesisStateFile=/zhejiang/genesis.ssz"
    else
        LODESTAR_NETWORK_ARG="--network $LODESTAR_NETWORK" 
    fi

    CMD="$PERF_PREFIX /usr/app/node_modules/.bin/lodestar beacon \
        $LODESTAR_NETWORK_ARG \
        --dataDir /ethclient/lodestar \
        --port $BN_P2P_PORT \
        --execution.urls $EC_ENGINE_ENDPOINT \
        --rest \
        --rest.address 0.0.0.0 \
        --rest.port ${BN_API_PORT:-5052} \
        --jwt-secret /secrets/jwtsecret \
        $BN_ADDITIONAL_FLAGS"

    if [ ! -z "$TTD_OVERRIDE" ]; then
        CMD="$CMD --terminal-total-difficulty-override $TTD_OVERRIDE"
    fi

    if [ ! -z "$MEV_BOOST_URL" ]; then
        CMD="$CMD --builder --builder.urls $MEV_BOOST_URL"
    fi

    if [ ! -z "$BN_MAX_PEERS" ]; then
        CMD="$CMD --targetPeers $BN_MAX_PEERS"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics --metrics.address 0.0.0.0 --metrics.port $BN_METRICS_PORT"
    fi

    if [ ! -z "$CHECKPOINT_SYNC_URL" ]; then
        CMD="$CMD --checkpointSyncUrl $CHECKPOINT_SYNC_URL"
    fi

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --bootnodes=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk,enr:-Ly4QOS00hvPDddEcCpwA1cMykWNdJUK50AjbRgbLZ9FLPyBa78i0NwsQZLSV67elpJU71L1Pt9yqVmE1C6XeSI-LV8Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhEDhTgGJc2VjcDI1NmsxoQIgMUMFvJGlr8dI1TEQy-K78u2TJE2rWvah9nGqLQCEGohzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MK4QMlRAwM7E8YBo6fqP7M2IWrjFHP35uC4pWIttUioZWOiaTl5zgZF2OwSxswTQwpiVCnj4n56bhy4NJVHSe682VWGAYYDHkp4h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhJK-7tSJc2VjcDI1NmsxoQLDq7LlsXIXAoJXPt7rqf6CES1Q40xPw2yW0RQ-Ly5S1YhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MS4QCgiQisRxtzXKlBqq_LN1CRUSGIpDKO4e2hLQsffp0BrC3A7-8F6kxHYtATnzcrsVOr8gnwmBnHYTFvE9UmT-0EHh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhKXoVKCJc2VjcDI1NmsxoQK6J-uvOXMf44iIlilx1uPWGRrrTntjLEFR2u-lHcHofIhzeW5jbmV0c4gAAAAAAAAAAIN0Y3CCIyiDdWRwgiMo,enr:-LK4QOQd-elgl_-dcSoUyHDbxBFNgQ687lzcKJiSBtpCyPQ0DinWSd2PKdJ4FHMkVLWD-oOquXPKSMtyoKpI0-Wo_38Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhES3DaqJc2VjcDI1NmsxoQNIf37JZx-Lc8pnfDwURcHUqLbIEZ1RoxjZuBRtEODseYN0Y3CCIyiDdWRwgiMo,enr:-KG4QLNORYXUK76RPDI4rIVAqX__zSkc5AqMcwAketVzN9YNE8FHSu1im3qJTIeuwqI5JN5SPVsiX7L9nWXgWLRUf6sDhGV0aDKQ7ijXswAAAHJGBQAAAAAAAIJpZIJ2NIJpcIShI5NiiXNlY3AyNTZrMaECpA_KefrVAueFWiLLDZKQPPVOxMuxGogPrI474FaS-x2DdGNwgiMog3VkcIIjKA"
    fi

    exec ${CMD}

fi

# Nimbus startup
if [ "$CC_CLIENT" = "nimbus" ]; then

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

    CMD="$PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_beacon_node \
        --non-interactive \
        --enr-auto-update \
        --network=$NIMBUS_NETWORK \
        --data-dir=/ethclient/nimbus \
        --tcp-port=$BN_P2P_PORT \
        --udp-port=$BN_P2P_PORT \
        --web3-url=$EC_ENGINE_ENDPOINT \
        --rest \
        --rest-address=0.0.0.0 \
        --rest-port=${BN_API_PORT:-5052} \
        --jwt-secret=/secrets/jwtsecret \
        $BN_ADDITIONAL_FLAGS"

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

    if [ ! -z "$NIMBUS_PRUNING_MODE" ]; then
        CMD="$CMD --history=$NIMBUS_PRUNING_MODE"
    fi

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --bootstrap-node=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk,enr:-Ly4QOS00hvPDddEcCpwA1cMykWNdJUK50AjbRgbLZ9FLPyBa78i0NwsQZLSV67elpJU71L1Pt9yqVmE1C6XeSI-LV8Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhEDhTgGJc2VjcDI1NmsxoQIgMUMFvJGlr8dI1TEQy-K78u2TJE2rWvah9nGqLQCEGohzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MK4QMlRAwM7E8YBo6fqP7M2IWrjFHP35uC4pWIttUioZWOiaTl5zgZF2OwSxswTQwpiVCnj4n56bhy4NJVHSe682VWGAYYDHkp4h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhJK-7tSJc2VjcDI1NmsxoQLDq7LlsXIXAoJXPt7rqf6CES1Q40xPw2yW0RQ-Ly5S1YhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MS4QCgiQisRxtzXKlBqq_LN1CRUSGIpDKO4e2hLQsffp0BrC3A7-8F6kxHYtATnzcrsVOr8gnwmBnHYTFvE9UmT-0EHh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhKXoVKCJc2VjcDI1NmsxoQK6J-uvOXMf44iIlilx1uPWGRrrTntjLEFR2u-lHcHofIhzeW5jbmV0c4gAAAAAAAAAAIN0Y3CCIyiDdWRwgiMo,enr:-LK4QOQd-elgl_-dcSoUyHDbxBFNgQ687lzcKJiSBtpCyPQ0DinWSd2PKdJ4FHMkVLWD-oOquXPKSMtyoKpI0-Wo_38Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhES3DaqJc2VjcDI1NmsxoQNIf37JZx-Lc8pnfDwURcHUqLbIEZ1RoxjZuBRtEODseYN0Y3CCIyiDdWRwgiMo,enr:-KG4QLNORYXUK76RPDI4rIVAqX__zSkc5AqMcwAketVzN9YNE8FHSu1im3qJTIeuwqI5JN5SPVsiX7L9nWXgWLRUf6sDhGV0aDKQ7ijXswAAAHJGBQAAAAAAAIJpZIJ2NIJpcIShI5NiiXNlY3AyNTZrMaECpA_KefrVAueFWiLLDZKQPPVOxMuxGogPrI474FaS-x2DdGNwgiMog3VkcIIjKA"
    fi

    exec ${CMD}

fi

# Prysm startup
if [ "$CC_CLIENT" = "prysm" ]; then

    # Get Prater SSZ if necessary
    if [ "$NETWORK" = "prater" -o "$NETWORK" = "devnet" ]; then
        if [ ! -f "/validators/genesis-prater.ssz" ]; then
            wget "https://github.com/eth-clients/eth2-networks/raw/master/shared/prater/genesis.ssz" -O "/validators/genesis-prater.ssz"
        fi
    fi

    CMD="$PERF_PREFIX /app/cmd/beacon-chain/beacon-chain \
        --accept-terms-of-use \
        $PRYSM_NETWORK \
        $PRYSM_GENESIS_STATE \
        --datadir /ethclient/prysm \
        --p2p-tcp-port $BN_P2P_PORT \
        --p2p-udp-port $BN_P2P_PORT \
        --execution-endpoint $EC_ENGINE_ENDPOINT \
        --rpc-host 0.0.0.0 \
        --rpc-port ${BN_RPC_PORT:-5053} \
        --grpc-gateway-host 0.0.0.0 \
        --grpc-gateway-port ${BN_API_PORT:-5052} \
        --eth1-header-req-limit 150 \
        --jwt-secret=/secrets/jwtsecret \
        --api-timeout 600 \
        $BN_ADDITIONAL_FLAGS"

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

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --bootstrap-node=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk \
        --bootstrap-node=enr:-Ly4QOS00hvPDddEcCpwA1cMykWNdJUK50AjbRgbLZ9FLPyBa78i0NwsQZLSV67elpJU71L1Pt9yqVmE1C6XeSI-LV8Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhEDhTgGJc2VjcDI1NmsxoQIgMUMFvJGlr8dI1TEQy-K78u2TJE2rWvah9nGqLQCEGohzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA \
        --bootstrap-node=enr:-MK4QMlRAwM7E8YBo6fqP7M2IWrjFHP35uC4pWIttUioZWOiaTl5zgZF2OwSxswTQwpiVCnj4n56bhy4NJVHSe682VWGAYYDHkp4h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhJK-7tSJc2VjcDI1NmsxoQLDq7LlsXIXAoJXPt7rqf6CES1Q40xPw2yW0RQ-Ly5S1YhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA \
        --bootstrap-node=enr:-MS4QCgiQisRxtzXKlBqq_LN1CRUSGIpDKO4e2hLQsffp0BrC3A7-8F6kxHYtATnzcrsVOr8gnwmBnHYTFvE9UmT-0EHh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhKXoVKCJc2VjcDI1NmsxoQK6J-uvOXMf44iIlilx1uPWGRrrTntjLEFR2u-lHcHofIhzeW5jbmV0c4gAAAAAAAAAAIN0Y3CCIyiDdWRwgiMo \
        --bootstrap-node=enr:-LK4QOQd-elgl_-dcSoUyHDbxBFNgQ687lzcKJiSBtpCyPQ0DinWSd2PKdJ4FHMkVLWD-oOquXPKSMtyoKpI0-Wo_38Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhES3DaqJc2VjcDI1NmsxoQNIf37JZx-Lc8pnfDwURcHUqLbIEZ1RoxjZuBRtEODseYN0Y3CCIyiDdWRwgiMo \
        --bootstrap-node=enr:-KG4QLNORYXUK76RPDI4rIVAqX__zSkc5AqMcwAketVzN9YNE8FHSu1im3qJTIeuwqI5JN5SPVsiX7L9nWXgWLRUf6sDhGV0aDKQ7ijXswAAAHJGBQAAAAAAAIJpZIJ2NIJpcIShI5NiiXNlY3AyNTZrMaECpA_KefrVAueFWiLLDZKQPPVOxMuxGogPrI474FaS-x2DdGNwgiMog3VkcIIjKA"
    fi

    exec ${CMD}

fi

# Teku startup
if [ "$CC_CLIENT" = "teku" ]; then

    CMD="$PERF_PREFIX /opt/teku/bin/teku \
        --network=$TEKU_NETWORK \
        --data-path=/ethclient/teku \
        --p2p-port=$BN_P2P_PORT \
        --ee-endpoint=$EC_ENGINE_ENDPOINT \
        --rest-api-enabled \
        --rest-api-interface=0.0.0.0 \
        --rest-api-port=${BN_API_PORT:-5052} \
        --rest-api-host-allowlist=* \
        --eth1-deposit-contract-max-request-size=150 \
        --log-destination=CONSOLE \
        --ee-jwt-secret-file=/secrets/jwtsecret \
        --validators-proposer-default-fee-recipient=$RETH_ADDRESS \
        $BN_ADDITIONAL_FLAGS"

    if [ "$TEKU_ARCHIVE_MODE" = "true" ]; then
        CMD="$CMD --data-storage-mode=archive"
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

    if [ "$NETWORK" = "zhejiang" ]; then
        CMD="$CMD --initial-state=/zhejiang/genesis.ssz \
        --Xee-version=kilnv2 \
        --p2p-discovery-bootnodes=enr:-Iq4QMCTfIMXnow27baRUb35Q8iiFHSIDBJh6hQM5Axohhf4b6Kr_cOCu0htQ5WvVqKvFgY28893DHAg8gnBAXsAVqmGAX53x8JggmlkgnY0gmlwhLKAlv6Jc2VjcDI1NmsxoQK6S-Cii_KmfFdUJL2TANL3ksaKUnNXvTCv1tLwXs0QgIN1ZHCCIyk,enr:-Ly4QOS00hvPDddEcCpwA1cMykWNdJUK50AjbRgbLZ9FLPyBa78i0NwsQZLSV67elpJU71L1Pt9yqVmE1C6XeSI-LV8Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhEDhTgGJc2VjcDI1NmsxoQIgMUMFvJGlr8dI1TEQy-K78u2TJE2rWvah9nGqLQCEGohzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MK4QMlRAwM7E8YBo6fqP7M2IWrjFHP35uC4pWIttUioZWOiaTl5zgZF2OwSxswTQwpiVCnj4n56bhy4NJVHSe682VWGAYYDHkp4h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhJK-7tSJc2VjcDI1NmsxoQLDq7LlsXIXAoJXPt7rqf6CES1Q40xPw2yW0RQ-Ly5S1YhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-MS4QCgiQisRxtzXKlBqq_LN1CRUSGIpDKO4e2hLQsffp0BrC3A7-8F6kxHYtATnzcrsVOr8gnwmBnHYTFvE9UmT-0EHh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhKXoVKCJc2VjcDI1NmsxoQK6J-uvOXMf44iIlilx1uPWGRrrTntjLEFR2u-lHcHofIhzeW5jbmV0c4gAAAAAAAAAAIN0Y3CCIyiDdWRwgiMo,enr:-LK4QOQd-elgl_-dcSoUyHDbxBFNgQ687lzcKJiSBtpCyPQ0DinWSd2PKdJ4FHMkVLWD-oOquXPKSMtyoKpI0-Wo_38Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDuKNezAAAAckYFAAAAAAAAgmlkgnY0gmlwhES3DaqJc2VjcDI1NmsxoQNIf37JZx-Lc8pnfDwURcHUqLbIEZ1RoxjZuBRtEODseYN0Y3CCIyiDdWRwgiMo,enr:-KG4QLNORYXUK76RPDI4rIVAqX__zSkc5AqMcwAketVzN9YNE8FHSu1im3qJTIeuwqI5JN5SPVsiX7L9nWXgWLRUf6sDhGV0aDKQ7ijXswAAAHJGBQAAAAAAAIJpZIJ2NIJpcIShI5NiiXNlY3AyNTZrMaECpA_KefrVAueFWiLLDZKQPPVOxMuxGogPrI474FaS-x2DdGNwgiMog3VkcIIjKA \
        --p2p-static-peers=/ip4/64.225.78.1/tcp/9000/p2p/16Uiu2HAkwbLbPXhPua835ErpoywHmgog4oydobcj3uKtww8UmW3b,/ip4/146.190.238.212/tcp/9000/p2p/16Uiu2HAm8bVLELrPczXQesjUYF8EetaKokgrdgZKj8814ZiGNggk,/ip4/165.232.84.160/tcp/9000/p2p/16Uiu2HAm7xM7nYVz3U9iWGH6NwExZTWtJGGeZ7ejQrcuUFUwtQmH,/ip4/68.183.13.170/udp/9000/p2p/16Uiu2HAmHXzTmWAtVexas5YskEpbcyDQ5Qck3jdLgErWumjKExUx"
    fi

    exec ${CMD}

fi
