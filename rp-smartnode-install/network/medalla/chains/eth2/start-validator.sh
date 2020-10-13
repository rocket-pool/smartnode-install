#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Client version numbers for graffiti
ROCKET_POOL_VERSION="v0.0.4"
LIGHTHOUSE_VERSION="v0.2.13"
PRYSM_VERSION="v1.0.0-alpha.29"


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    if [ ! -z "$CUSTOM_GRAFFITI" ]; then
        GRAFFITI="$CUSTOM_GRAFFITI"
    else
        GRAFFITI="RP $ROCKET_POOL_VERSION / LH $LIGHTHOUSE_VERSION"
    fi

    /usr/local/bin/lighthouse validator --testnet medalla --datadir /data/validators/lighthouse --secrets-dir /data/validators/lighthouse/secrets --server "http://$ETH2_PROVIDER" --graffiti "$GRAFFITI"

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    if [ ! -z "$CUSTOM_GRAFFITI" ]; then
        GRAFFITI="$CUSTOM_GRAFFITI"
    else
        GRAFFITI="RP $ROCKET_POOL_VERSION / PR $PRYSM_VERSION"
    fi

    /app/validator/image.binary --wallet-dir /data/validators/prysm --wallet-password-file /data/password --beacon-rpc-provider "$ETH2_PROVIDER" --graffiti "$GRAFFITI"

fi

