#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# only show client identifier if version string is under 9 characters
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
elif [ "$NETWORK" = "kiln" ]; then
    LH_NETWORK="kiln"
    PRYSM_NETWORK="--kiln"
    TEKU_NETWORK="kiln"
elif [ "$NETWORK" = "ropsten" ]; then
    LH_NETWORK="ropsten"
    NIMBUS_NETWORK="ropsten"
    PRYSM_NETWORK="--ropsten"
    TEKU_NETWORK="ropsten"
else
    echo "Unknown network [$NETWORK]"
    exit 1
fi


# Lighthouse startup
if [ "$CC_CLIENT" = "lighthouse" ]; then

    # Copy the default fee recipient file from the template
    if [ ! -f "/validators/lighthouse/$FEE_RECIPIENT_FILE" ]; then
        cp "/fr-default/lighthouse" "/validators/lighthouse/$FEE_RECIPIENT_FILE"
    fi

    # Set up the CC + fallback string
    CC_URL_STRING=$CC_API_ENDPOINT
    if [ ! -z "$FALLBACK_CC_API_ENDPOINT" ]; then
        CC_URL_STRING="$CC_API_ENDPOINT,$FALLBACK_CC_API_ENDPOINT"
    fi

    CMD="/usr/local/bin/lighthouse validator --network $LH_NETWORK --datadir /validators/lighthouse --init-slashing-protection --logfile-max-number 0 --beacon-nodes $CC_URL_STRING --suggested-fee-recipient $(cat /validators/lighthouse/$FEE_RECIPIENT_FILE) $VC_ADDITIONAL_FLAGS"

    if [ "$DOPPELGANGER_DETECTION" = "true" ]; then
        CMD="$CMD --enable-doppelganger-protection"
    fi

    if [ "$NETWORK" = "ropsten" -o "$NETWORK" = "kiln" ]; then
        CMD="$CMD --private-tx-proposals"
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

    # Nimbus won't start unless the validator directories already exist
    mkdir -p /validators/nimbus/validators
    mkdir -p /validators/nimbus/secrets

    # Copy the default fee recipient file from the template
    if [ ! -f "/validators/nimbus/$FEE_RECIPIENT_FILE" ]; then
        cp "/fr-default/nimbus" "/validators/nimbus/$FEE_RECIPIENT_FILE"
    fi

    CMD="$PERF_PREFIX /home/user/nimbus-eth2/build/nimbus_validator_client --non-interactive  --beacon-node=$CC_API_ENDPOINT --data-dir=/ethclient/nimbus_vc --insecure-netkey-password=true --validators-dir=/validators/nimbus/validators --secrets-dir=/validators/nimbus/secrets  $VC_ADDITIONAL_FLAGS"
    # --network=$NIMBUS_NETWORK
    # --insecure-netkey-password=true
    # --doppelganger-detection=$DOPPELGANGER_DETECTION
    # --suggested-fee-recipient=$(cat /validators/nimbus/$FEE_RECIPIENT_FILE)

    #if [ "$ENABLE_METRICS" = "true" ]; then
    #    CMD="$CMD --metrics --metrics-address=0.0.0.0 --metrics-port=$VC_METRICS_PORT"
    #fi

    # Graffiti breaks if it's in the CMD string instead of here because of spaces
    exec ${CMD} --graffiti="$GRAFFITI"

fi


# Prysm startup
if [ "$CC_CLIENT" = "prysm" ]; then

    # Make the Prysm dir
    mkdir -p /validators/prysm-non-hd/

    # Copy the default fee recipient file from the template
    if [ ! -f "/validators/prysm-non-hd/$FEE_RECIPIENT_FILE" ]; then
        cp "/fr-default/prysm" "/validators/prysm-non-hd/$FEE_RECIPIENT_FILE"
    fi

    # Get rid of the protocol prefix
    CC_RPC_ENDPOINT=$(echo $CC_RPC_ENDPOINT | sed -E 's/.*\:\/\/(.*)/\1/')
    if [ ! -z "$FALLBACK_CC_RPC_ENDPOINT" ]; then
        FALLBACK_CC_RPC_ENDPOINT=$(echo $FALLBACK_CC_RPC_ENDPOINT | sed -E 's/.*\:\/\/(.*)/\1/')
    fi

    # Set up the CC + fallback string
    CC_URL_STRING=$CC_RPC_ENDPOINT
    if [ ! -z "$FALLBACK_CC_RPC_ENDPOINT" ]; then
        CC_URL_STRING="$CC_RPC_ENDPOINT,$FALLBACK_CC_RPC_ENDPOINT"
    fi

    CMD="/app/cmd/validator/validator --accept-terms-of-use $PRYSM_NETWORK --wallet-dir /validators/prysm-non-hd --wallet-password-file /validators/prysm-non-hd/direct/accounts/secret --beacon-rpc-provider $CC_URL_STRING --suggested-fee-recipient $(cat /validators/prysm-non-hd/$FEE_RECIPIENT_FILE) $VC_ADDITIONAL_FLAGS"

    if [ "$NETWORK" = "ropsten" -o "$NETWORK" = "kiln" -o "$NETWORK" = "prater" ]; then
        CMD="$CMD --enable-builder"
    fi

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

    # Copy the default fee recipient file from the template
    if [ ! -f "/validators/teku/$FEE_RECIPIENT_FILE" ]; then
        cp "/fr-default/teku" "/validators/teku/$FEE_RECIPIENT_FILE"
    fi

    CMD="/opt/teku/bin/teku validator-client --network=auto --data-path=/validators/teku --validator-keys=/validators/teku/keys:/validators/teku/passwords --beacon-node-api-endpoint=$CC_API_ENDPOINT --validators-keystore-locking-enabled=false --log-destination=CONSOLE --validators-proposer-default-fee-recipient=$(cat /validators/teku/$FEE_RECIPIENT_FILE) $VC_ADDITIONAL_FLAGS"

    if [ "$NETWORK" = "ropsten" -o "$NETWORK" = "kiln" ]; then
        CMD="$CMD --validators-builder-registration-default-enabled=true"
    fi

    if [ "$ENABLE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$VC_METRICS_PORT --metrics-host-allowlist=*"
    fi

    if [ "$ENABLE_BITFLY_NODE_METRICS" = "true" ]; then
        CMD="$CMD --metrics-publish-endpoint=$BITFLY_NODE_METRICS_ENDPOINT?apikey=$BITFLY_NODE_METRICS_SECRET&machine=$BITFLY_NODE_METRICS_MACHINE_NAME"
    fi

    exec ${CMD} --validators-graffiti="$GRAFFITI"

fi

