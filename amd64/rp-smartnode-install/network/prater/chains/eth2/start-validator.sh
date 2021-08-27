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

    exec /usr/local/bin/lighthouse validator --network prater --datadir /validators/lighthouse --init-slashing-protection --beacon-node "http://$ETH2_PROVIDER" --graffiti "$GRAFFITI"

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

    exec /app/cmd/validator/validator --accept-terms-of-use --prater --wallet-dir /validators/prysm-non-hd --wallet-password-file /validators/prysm-non-hd/direct/accounts/secret --beacon-rpc-provider "$ETH2_PROVIDER" --graffiti "$GRAFFITI"

fi


# Teku startup
if [ "$CLIENT" = "teku" ]; then

    exec /opt/teku/bin/teku validator-client --network=prater --validator-keys=/validators/teku/keys:/validators/teku/passwords --beacon-node-api-endpoint="http://$ETH2_PROVIDER" --validators-graffiti="$GRAFFITI"

fi

