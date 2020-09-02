#!/bin/bash

##
# Rocket Pool service installation script
# Prints progress messages to stdout
# All command output is redirected to stderr
##


##
# Config
##


# The total number of steps in the installation process
TOTAL_STEPS="7"
# The Rocket Pool user data path
RP_PATH="$HOME/.rocketpool"
# The default smart node package version to download
PACKAGE_VERSION="latest"
# The default network to run Rocket Pool on
NETWORK="medalla"


##
# Utils
##


# Print a failure message to stderr and exit
fail() {
    MESSAGE=$1
    >&2 echo "$MESSAGE"
    exit 1
}


# Print progress
progress() {
    STEP_NUMBER=$1
    MESSAGE=$2
    echo "$STEP_NUMBER/$TOTAL_STEPS $MESSAGE"
}


##
# Initialization
##


# Parse arguments
while getopts "in:v:" FLAG; do
    case "$FLAG" in
        i) IGNORE_DEPS=true ;;
        n) NETWORK="$OPTARG" ;;
        v) PACKAGE_VERSION="$OPTARG" ;;
        *) fail "Incorrect usage." ;;
    esac
done


# Get the platform type
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Linux" ]; then
    PLATFORM=$(lsb_release -si)
fi


# Get package files URL
if [ "$PACKAGE_VERSION" = "latest" ]; then
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/latest/download/rp-smartnode-install.tar.xz"
else
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/download/$PACKAGE_VERSION/rp-smartnode-install.tar.xz"
fi


# Create temporary data folder; clean up on exit
TEMPDIR=$(mktemp -d 2>/dev/null) || fail "Could not create temporary data directory."
trap 'rm -rf "$TEMPDIR"' EXIT


# Get temporary data paths
PACKAGE_FILES_PATH="$TEMPDIR/rp-smartnode-install"
NETWORK_FILES_PATH="$PACKAGE_FILES_PATH/network/$NETWORK"


##
# Installation
##


# OS dependencies
if [ -z "$IGNORE_DEPS" ]; then
case "$PLATFORM" in

    # Ubuntu
    Ubuntu)

        # Install OS dependencies
        progress 1 "Installing OS dependencies..."
        >&2 sudo apt-get -y update
        >&2 sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

        # Install docker
        progress 2 "Installing docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        >&2 sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        >&2 sudo apt-get -y update
        >&2 sudo apt-get -y install docker-ce docker-ce-cli containerd.io

        # Install docker-compose
        progress 3 "Installing docker-compose..."
        >&2 sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        >&2 sudo chmod a+rx /usr/local/bin/docker-compose

        # Add user to docker group
        progress 4 "Adding user to docker group..."
        >&2 sudo groupadd docker
        >&2 sudo usermod -aG docker $USER

    ;;

    # MacOS
    Darwin)
    ;;

    # Unsupported OS
    *)
        fail "Sorry, the '$PLATFORM' operating system is not supported."
    ;;

esac
fi


# Create ~/.rocketpool dir & files
progress 5 "Creating Rocket Pool user data directory..."
>&2 mkdir -p "$RP_PATH/data/validators" || fail "Could not create the Rocket Pool user data directory."
>&2 touch -a "$RP_PATH/settings.yml" || fail "Could not create the Rocket Pool user settings file."


# Download and extract package files
progress 6 "Downloading Rocket Pool package files..."
curl -L "$PACKAGE_URL" | tar -xJ -C "$TEMPDIR" || fail "Could not download and extract the Rocket Pool package files."
>&2 test -d "$PACKAGE_FILES_PATH" || fail "Could not extract the Rocket Pool package files."


# Copy package files
progress 7 "Copying package files to Rocket Pool user data directory..."
>&2 test -d "$NETWORK_FILES_PATH" || fail "No package files were found for the selected network."
>&2 cp -r "$NETWORK_FILES_PATH/"* "$RP_PATH" || fail "Could not copy network package files to the Rocket Pool user data directory."
>&2 find "$RP_PATH" -name "*.sh" -exec chmod +x {} \; || fail "Could not set executable permissions on package files."

