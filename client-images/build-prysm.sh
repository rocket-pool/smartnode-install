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

# Builds the Prysm binaries from source
# NOTE: Requires bazel (or bazelisk) to be installed into the path, e.g. sudo wget https://github.com/bazelbuild/bazelisk/releases/download/v1.18.0/bazelisk-linux-amd64 -O /usr/local/bin/bazel
build_binaries() {
    echo -n "Building x64 binaries... "
    cd prysm || fail "Directory ${PWD}/prysm does not exist or you don't have permissions to access it - this should be the Prysm source dir."
    bazel build --config=release --config=linux_amd64 //cmd/beacon-chain //cmd/validator
    mkdir -p ../amd64
    cp bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain ../amd64/
    cp bazel-bin/cmd/validator/validator_/validator ../amd64/
    echo "done!"

    echo -n "Building arm64 binaries... "
    bazel build --config=release --config=linux_arm64_docker //cmd/beacon-chain //cmd/validator
    mkdir -p ../arm64
    cp bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain ../arm64/
    cp bazel-bin/cmd/validator/validator_/validator ../arm64/
    echo "done!"
}

# Builds the Docker images and pushes them to Docker Hub
# NOTE: This only works for Prysm v4.1.0 and higher since that merges the modern and portable x64 versions
download_binaries() {
    echo -n "Downloading x64 binaries..."
    mkdir -p amd64
    cd amd64 || fail "Directory ${PWD}/amd64 does not exist or you don't have permissions to access it."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/beacon-chain-$VERSION-linux-amd64 -O ./beacon-chain || fail "Error downloading amd64 beacon-client."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/validator-$VERSION-linux-amd64 -O ./validator || fail "Error downloading amd64 validator."
    echo "done!"

    echo -n "Downloading arm64 binaries..."
    mkdir -p ../arm64
    cd ../arm64 || fail "Directory ${PWD}/arm64 does not exist or you don't have permissions to access it."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/beacon-chain-$VERSION-linux-arm64 -O ./beacon-chain || fail "Error downloading arm64 beacon-client."
    wget https://github.com/prysmaticlabs/prysm/releases/download/$VERSION/validator-$VERSION-linux-arm64 -O ./validator || fail "Error downloading arm64 validator."
    echo "done!"
    cd ..
}

# Builds the Docker images and pushes them to Docker Hub
# NOTE: This only works for Prysm v4.1.0 and higher since that merges the modern and portable x64 versions
build_images() {
    echo -n "Building x64 image... "
    cd amd64 || fail "Directory ${PWD}/amd64 does not exist or you don't have permissions to access it."
    chmod +x ./beacon-chain ./validator
    docker buildx build --platform=linux/amd64 -t rocketpool/prysm:$VERSION-amd64 -f ../Dockerfile.prysm --load . || fail "Error building amd64 image."
    echo "done!"

    echo -n "Building arm64 image... "
    cd ../arm64 || fail "Directory ${PWD}/arm64 does not exist or you don't have permissions to access it."
    chmod +x ./beacon-chain ./validator
    docker buildx build --platform=linux/arm64 -t rocketpool/prysm:$VERSION-arm64 -f ../Dockerfile.prysm --load . || fail "Error building arm64 image."
    echo "done!"

    echo -n "Pushing to Docker Hub... "
    docker push rocketpool/prysm:$VERSION-amd64 || fail "Error pushing amd64 image to Docker Hub."
    docker push rocketpool/prysm:$VERSION-arm64 || fail "Error pushing arm64 image to Docker Hub."
    echo "done!"
    
    cd ..
}


# Builds the Docker Manifests and pushes them to Docker Hub
build_docker_manifests() {
    echo -n "Building Docker manifest... "
    rm -f ~/.docker/manifests/docker.io_rocketpool_prysm-$VERSION
    docker manifest create rocketpool/prysm:$VERSION --amend rocketpool/prysm:$VERSION-amd64 --amend rocketpool/prysm:$VERSION-arm64
    echo "done!"

    echo -n "Pushing to Docker Hub... "
    docker manifest push --purge rocketpool/prysm:$VERSION
    echo "done!"
}

# Print usage
usage() {
    echo "Usage: build-prysm.sh [options] -v <version number>"
    echo "This script assumes it is in a directory that contains subdirectories for amd64 binaries, arm64 binaries, and the Prysm source code."
    echo "Options:"
    echo $'\t-b\tBuild the Prysm beacon-chain and validator binaries from source'
    echo $'\t-d\tDownload the Prysm beacoin-chain and validator binaries from Github'
    echo $'\t-i\tBuild the Prysm Docker images and push them to Docker Hub'
    echo $'\t-n\tBuild the Prysm manifest tag and push it to Docker Hub'
    exit 0
}

# =================
# === Main Body ===
# =================

# Parse arguments
while getopts "bdinv:" FLAG; do
    case "$FLAG" in
        b) BUILD=true ;;
        d) DOWNLOAD=true ;;
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
if [ "$BUILD" = true ]; then
    build_binaries
elif [ "$DOWNLOAD" = true ]; then
    download_binaries
fi
if [ "$IMAGE" = true ]; then
    build_images
fi
if [ "$MANIFEST" = true ]; then
    build_docker_manifests
fi
