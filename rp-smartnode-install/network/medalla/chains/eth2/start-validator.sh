#!/bin/sh
# This script launches ETH2 validator clients for Rocket Pool's docker stack; only edit if you know what you're doing ;)


# Lighthouse startup
if [ "$CLIENT" = "lighthouse" ]; then

    /usr/local/bin/lighthouse validator --testnet medalla --datadir /data/validators/lighthouse --secrets-dir /data/validators/lighthouse/secrets --server "http://$ETH2_PROVIDER"

fi


# Prysm startup
if [ "$CLIENT" = "prysm" ]; then

    /app/validator/image.binary --wallet-dir /data/validators/prysm --wallet-password-file /data/password --beacon-rpc-provider "$ETH2_PROVIDER"

fi

