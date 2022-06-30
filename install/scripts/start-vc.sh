#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)

# Slashing database import / export variables
SLASHING_DB_FILE="/validators/slashing_protection.json"
SLASHING_DB_IMPORT_INDICATOR="/validators/import.lock"
SLASHING_DB_EXPORT_INDICATOR="/validators/export.lock"

# Only show client identifier if version string is under 8 characters
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

# Set up the network-based flags
if [ "$NETWORK" = "mainnet" ]; then
    LH_NETWORK="mainnet"
    PRYSM_NETWORK="--mainnet"
    TEKU_NETWORK="mainnet"
elif [ "$NETWORK" = "prater" ]; then
    LH_NETWORK="prater"
    PRYSM_NETWORK="--prater"
    TEKU_NETWORK="prater"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi


# Import the slashing DB
if [ -f "$SLASHING_DB_IMPORT_INDICATOR" ]; then
    if [ "$CC_CLIENT" = "lighthouse" ]; then
        /usr/local/bin/lighthouse account validator slashing-protection import $SLASHING_DB_FILE --datadir /validators/lighthouse --network $LH_NETWORK && rm $SLASHING_DB_IMPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "nimbus" ]; then
        /home/user/nimbus-eth2/build/nimbus_beacon_node slashingdb import $SLASHING_DB_FILE --validators-dir=/validators/nimbus/validators && rm $SLASHING_DB_IMPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "prysm" ]; then
        /app/cmd/validator/validator slashing-protection-history import $PRYSM_NETWORK --accept-terms-of-use --datadir /validators/prysm-non-hd/direct --slashing-protection-json-file=$SLASHING_DB_FILE && rm $SLASHING_DB_IMPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "teku" ]; then
       /opt/teku/bin/teku slashing-protection import --data-path=/validators/teku--from=$SLASHING_DB_FILE && rm $SLASHING_DB_IMPORT_INDICATOR
    fi

    exit 0
fi

# Export the slashing DB
if [ -f "$SLASHING_DB_EXPORT_INDICATOR" ]; then
    if [ "$CC_CLIENT" = "lighthouse" ]; then
        /usr/local/bin/lighthouse account validator slashing-protection export $SLASHING_DB_FILE --datadir /validators/lighthouse --network $LH_NETWORK && rm $SLASHING_DB_EXPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "nimbus" ]; then
        /home/user/nimbus-eth2/build/nimbus_beacon_node slashingdb export $SLASHING_DB_FILE --validators-dir=/validators/nimbus/validators && rm $SLASHING_DB_EXPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "prysm" ]; then
        /app/cmd/validator/validator slashing-protection-history export $PRYSM_NETWORK --accept-terms-of-use --datadir /validators/prysm-non-hd/direct --slashing-protection-export-dir=/validators && rm $SLASHING_DB_EXPORT_INDICATOR
    fi

    if [ "$CC_CLIENT" = "teku" ]; then
       /opt/teku/bin/teku slashing-protection export --data-path=/validators/teku--to=$SLASHING_DB_FILE && rm $SLASHING_DB_EXPORT_INDICATOR
    fi

    exit 0
fi


# Lighthouse startup
if [ "$CC_CLIENT" = "lighthouse" ]; then

    CMD="/usr/local/bin/lighthouse validator --network $LH_NETWORK --datadir /validators/lighthouse --init-slashing-protection --logfile-max-number 0 --beacon-nodes $CC_API_ENDPOINT $VC_ADDITIONAL_FLAGS"

    if [ "$DOPPELGANGER_DETECTION" = "true" ]; then
        CMD="$CMD --enable-doppelganger-protection"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics --metrics-address 0.0.0.0 --metrics-port $VC_METRICS_PORT"
    fi

    if [ "$ENABLE_BITFLY_NODE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-endpoint $BITFLY_NODE_METRICS_ENDPOINT?apikey=$BITFLY_NODE_METRICS_SECRET&machine=$BITFLY_NODE_METRICS_MACHINE_NAME"
    fi

    exec ${CMD} --graffiti "$GRAFFITI"

fi


# Nimbus startup
if [ "$CC_CLIENT" = "nimbus" ]; then

    # Do nothing since the validator is built into the beacon client
    trap 'kill -9 $sleep_pid' INT TERM
    sleep infinity &
    sleep_pid=$!
    wait

fi


# Prysm startup
if [ "$CC_CLIENT" = "prysm" ]; then

    # Get rid of the protocol prefix
    CC_RPC_ENDPOINT=$(echo $CC_RPC_ENDPOINT | sed -E 's/.*\:\/\/(.*)/\1/')

    CMD="/app/cmd/validator/validator --accept-terms-of-use $PRYSM_NETWORK --wallet-dir /validators/prysm-non-hd --wallet-password-file /validators/prysm-non-hd/direct/accounts/secret --beacon-rpc-provider $CC_RPC_ENDPOINT $VC_ADDITIONAL_FLAGS"

    if [ "$DOPPELGANGER_DETECTION" = "true" ]; then
        CMD="$CMD --enable-doppelganger"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $VC_METRICS_PORT"
    else
        CMD="$CMD --disable-account-metrics"
    fi

    exec ${CMD} --graffiti "$GRAFFITI"

fi


# Teku startup
if [ "$CC_CLIENT" = "teku" ]; then

    # Teku won't start unless the validator directories already exist
    mkdir -p /validators/teku/keys
    mkdir -p /validators/teku/passwords

    # Remove any lock files that were left over accidentally after an unclean shutdown
    rm -f /validators/teku/keys/*.lock

    CMD="/opt/teku/bin/teku validator-client --network=auto --data-path=/validators/teku --validator-keys=/validators/teku/keys:/validators/teku/passwords --beacon-node-api-endpoint=$CC_API_ENDPOINT --validators-keystore-locking-enabled=false --log-destination=CONSOLE $VC_ADDITIONAL_FLAGS"

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$VC_METRICS_PORT --metrics-host-allowlist=*" 
    fi

    if [ "$ENABLE_BITFLY_NODE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-publish-endpoint=$BITFLY_NODE_METRICS_ENDPOINT?apikey=$BITFLY_NODE_METRICS_SECRET&machine=$BITFLY_NODE_METRICS_MACHINE_NAME"
    fi

    exec ${CMD} --validators-graffiti="$GRAFFITI"

fi

