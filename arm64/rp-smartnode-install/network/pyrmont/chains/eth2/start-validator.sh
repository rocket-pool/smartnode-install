#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Get graffiti text
GRAFFITI="RP $ROCKET_POOL_VERSION"
if [ ! -z "$CUSTOM_GRAFFITI" ]; then
    GRAFFITI="$GRAFFITI ($CUSTOM_GRAFFITI)"
fi


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    exec /usr/local/bin/lighthouse validator --network pyrmont --datadir /validators/lighthouse --init-slashing-protection --beacon-node "http://$ETH2_PROVIDER" --graffiti "$GRAFFITI"

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

    exec /app/cmd/validator/validator --accept-terms-of-use --pyrmont --wallet-dir /validators/prysm-non-hd --wallet-password-file /validators/prysm-non-hd/direct/accounts/secret --beacon-rpc-provider "$ETH2_PROVIDER" --graffiti "$GRAFFITI"

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    exec /opt/teku/bin/teku validator-client --network=pyrmont --validator-keys=/validators/teku/keys:/validators/teku/passwords --beacon-node-api-endpoint="http://$ETH2_PROVIDER" --validators-graffiti="$GRAFFITI"

fi

