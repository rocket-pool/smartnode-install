#!/bin/sh

LATEST_VERSION=$(curl --silent "https://api.github.com/repos/rocket-pool/smartnode-install/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
CURRENT_VERSION=$(docker exec rocketpool_node /go/bin/rocketpool --version | sed -E 's/rocketpool version (.*)/v\1/')

echo "# HELP rocketpool_version_update New Rocket Pool version available"
echo "# TYPE rocketpool_version_update gauge"
if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "rocketpool_version_update 0"
else
    echo "rocketpool_version_update 1"
fi
