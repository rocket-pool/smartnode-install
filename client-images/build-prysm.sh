#!/bin/bash

# =================
# === Functions ===
# =================

# Print a failure message to stderr and exit
fail() {
    MESSAGE=$1
    RED='\033[0;31m'
    RESET='\033[;0m'
    >&2 echo -e "\n${RED}**ERROR**\n$MESSAGE${RESET}\n"
    exit 1
}

# Builds the Docker images and pushes them to Docker Hub
build_images() {
    echo -n "Building x64 Modern image... "
    cd amd64-modern || fail "Directory ${PWD}/amd64-modern does not exist or you don't have permissions to access it."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/beacon-chain-$VERSION-modern-linux-amd64 -O ./beacon-chain || fail "Error downloading amd64-modern beacon-client."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/validator-$VERSION-linux-amd64 -O ./validator || fail "Error downloading amd64-modern validator."
    chmod +x ./beacon-chain ./validator
    docker buildx build --platform=linux/amd64 -t rocketpool/prysm:$VERSION-amd64-modern -f ../Dockerfile --load . || fail "Error building amd64 modern image."
    echo "done!"

    echo -n "Building x64 Portable image... "
    cd ../amd64-portable || fail "Directory ${PWD}/amd64-portable does not exist or you don't have permissions to access it."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/beacon-chain-$VERSION-linux-amd64 -O ./beacon-chain || fail "Error downloading amd64-portable beacon-client."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/validator-$VERSION-linux-amd64 -O ./validator || fail "Error downloading amd64-portable validator."
    chmod +x ./beacon-chain ./validator
    docker buildx build --platform=linux/amd64 -t rocketpool/prysm:$VERSION-amd64-portable -f ../Dockerfile --load . || fail "Error building amd64 portable image."

    echo -n "Building arm64 image... "
    cd ../arm64 || fail "Directory ${PWD}/arm64 does not exist or you don't have permissions to access it."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/beacon-chain-$VERSION-linux-arm64 -O ./beacon-chain || fail "Error downloading arm64 beacon-client."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/validator-$VERSION-linux-arm64 -O ./validator || fail "Error downloading arm64 validator."
    chmod +x ./beacon-chain ./validator
    docker buildx build --platform=linux/arm64 -t rocketpool/prysm:$VERSION-arm64 -f ../Dockerfile --load . || fail "Error building arm64 image."
    echo "done!"

    echo -n "Pushing to Docker Hub... "
    docker push rocketpool/prysm:$VERSION-amd64-modern || fail "Error pushing amd64 modern image to Docker Hub."
    docker push rocketpool/prysm:$VERSION-amd64-portable || fail "Error pushing amd64 portable image to Docker Hub."
    docker push rocketpool/prysm:$VERSION-arm64 || fail "Error pushing arm64 to Docker Hub."
    echo "done!"
    
    cd ..
}


# Builds the Docker Manifests and pushes them to Docker Hub
build_docker_manifests() {
    echo -n "Building Docker manifest... "
    rm -f ~/.docker/manifests/docker.io_rocketpool_prysm-$VERSION-modern
    rm -f ~/.docker/manifests/docker.io_rocketpool_prysm-$VERSION-portable
    rm -f ~/.docker/manifests/docker.io_rocketpool_prysm-$VERSION
    docker manifest create rocketpool/prysm:$VERSION-modern --amend rocketpool/prysm:$VERSION-amd64-modern --amend rocketpool/prysm:$VERSION-arm64
    docker manifest create rocketpool/prysm:$VERSION-portable --amend rocketpool/prysm:$VERSION-amd64-portable --amend rocketpool/prysm:$VERSION-arm64
    docker manifest create rocketpool/prysm:$VERSION --amend rocketpool/prysm:$VERSION-amd64-modern --amend rocketpool/prysm:$VERSION-arm64
    echo "done!"

    echo -n "Pushing to Docker Hub... "
    docker manifest push --purge rocketpool/prysm:$VERSION-modern
    docker manifest push --purge rocketpool/prysm:$VERSION-portable
    docker manifest push --purge rocketpool/prysm:$VERSION
    echo "done!"
}

# =================
# === Main Body ===
# =================

# Parse arguments
while getopts "acpdnlrfv:" FLAG; do
    case "$FLAG" in
        a) IMAGE=true MANIFEST=true ;;
        i) IMAGE=true ;;
        n) MANIFEST=true ;;
        v) VERSION="$OPTARG" ;;
        *) usage ;;
    esac
done
if [ -z "$VERSION" ]; then
    usage
fi

# Build the artifacts
if [ "$IMAGE" = true ]; then
    build_images
fi
if [ "$MANIFEST" = true ]; then
    build_docker_manifests
fi