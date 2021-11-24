#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


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

    CMD="/usr/local/bin/lighthouse validator --network prater --datadir /validators/lighthouse --init-slashing-protection --beacon-node $ETH2_PROVIDER"

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --metrics --metrics-address 0.0.0.0 --metrics-port $VALIDATOR_METRICS_PORT"
    fi

    exec ${CMD} --graffiti "$GRAFFITI"

fi


# Nimbus startup
if [ "$CLIENT" = "nimbus" ]; then

    # Do nothing since the validator is built into the beacon client
    trap 'kill -9 $sleep_pid' INT TERM
    sleep infinity &
    sleep_pid=$!
    wait

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    # Get rid of the protocol prefix
    ETH2_PROVIDER=$(echo $ETH2_PROVIDER | sed -E 's/.*\:\/\/(.*)/\1/')

    if [ -z "$ETH2_RPC_PORT" ]; then
        ETH2_RPC_PORT="5053"
    fi

    # Replace the HTTP port with Prysm's RPC port
    ETH2_RPC_PROVIDER="$( echo $ETH2_PROVIDER | grep -o '.*:' )$ETH2_RPC_PORT"

    CMD="/app/cmd/validator/validator --accept-terms-of-use --prater --wallet-dir /validators/prysm-non-hd --wallet-password-file /validators/prysm-non-hd/direct/accounts/secret --beacon-rpc-provider $ETH2_RPC_PROVIDER"

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --monitoring-host 0.0.0.0 --monitoring-port $VALIDATOR_METRICS_PORT"
    else
        CMD="$CMD --disable-account-metrics"
    fi

    exec ${CMD} --graffiti "$GRAFFITI"

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    # Teku won't start unless the validator directories already exist
    mkdir -p /validators/teku/keys
    mkdir -p /validators/teku/passwords
    
    # Remove any lock files that were left over accidentally after an unclean shutdown
    rm -f /validators/teku/keys/*.lock

    CMD="/opt/teku/bin/teku validator-client --network=prater --validator-keys=/validators/teku/keys:/validators/teku/passwords --beacon-node-api-endpoint=$ETH2_PROVIDER --validators-keystore-locking-enabled=false"

    if [ "$ENABLE_METRICS" -eq "1" ]; then
        CMD="$CMD --metrics-enabled=true --metrics-interface=0.0.0.0 --metrics-port=$VALIDATOR_METRICS_PORT --metrics-host-allowlist=*" 
    fi

    exec ${CMD} --validators-graffiti="$GRAFFITI"

fi

