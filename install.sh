#!/bin/sh

##
# Rocket Pool service installation script
# Prints progress messages to stdout
# All command output is redirected to stderr
##

COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[33m'
COLOR_RESET='\033[0m'

# Print a failure message to stderr and exit
fail() {
    MESSAGE=$1
    >&2 echo -e "\n${COLOR_RED}**ERROR**\n$MESSAGE${COLOR_RESET}"
    exit 1
}


# Get CPU architecture
UNAME_VAL=$(uname -m)
ARCH=""
case $UNAME_VAL in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)       fail "CPU architecture not supported: $UNAME_VAL" ;;
esac


# Get the platform type
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Linux" ]; then
    if command -v lsb_release &>/dev/null ; then
        PLATFORM=$(lsb_release -si)
    elif [ -f "/etc/centos-release" ]; then
        PLATFORM="CentOS"
    elif [ -f "/etc/fedora-release" ]; then
        PLATFORM="Fedora"
    fi
fi


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
NETWORK="mainnet"
# The version of docker-compose to install
DOCKER_COMPOSE_VERSION="1.29.2"


##
# Utils
##


# Print progress
progress() {
    STEP_NUMBER=$1
    MESSAGE=$2
    echo "Step $STEP_NUMBER of $TOTAL_STEPS: $MESSAGE"
}


# Docker installation steps
install_docker_compose() {
    if [ $ARCH = "amd64" ]; then
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || fail "Could not download docker-compose."
        sudo chmod a+x /usr/local/bin/docker-compose || fail "Could not set executable permissions on docker-compose."
    elif [ $ARCH = "arm64" ]; then
        if command -v apt &> /dev/null ; then
            sudo apt install -y libffi-dev libssl-dev
            sudo apt install -y python3 python3-pip
            sudo apt remove -y python-configparser
            pip3 install --upgrade docker-compose==$DOCKER_COMPOSE_VERSION
        else
            RED='\033[0;31m'
            echo ""
            echo -e "${RED}**ERROR**"
            echo "Automatic installation of docker-compose for the $PLATFORM operating system on ARM64 is not currently supported."
            echo "Please install docker-compose manually, then try this again with the '-d' flag to skip OS dependency installation."
            echo "Be sure to add yourself to the docker group (e.g. 'sudo usermod -aG docker $USER') after installing docker."
            echo "Log out and back in, or restart your system after you run this command."
            exit 1
        fi
    fi
}
add_user_docker() {
    sudo usermod -aG docker $USER || fail "Could not add user to docker group."
}


# Install
install() {


##
# Initialization
##


# Parse arguments
while getopts "dp:n:v:" FLAG; do
    case "$FLAG" in
        d) NO_DEPS=true ;;
        p) RP_PATH="$OPTARG" ;;
        n) NETWORK="$OPTARG" ;;
        v) PACKAGE_VERSION="$OPTARG" ;;
        *) fail "Incorrect usage." ;;
    esac
done


# Get package files URL
if [ "$PACKAGE_VERSION" = "latest" ]; then
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/latest/download/rp-smartnode-install-$ARCH.tar.xz"
else
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/download/$PACKAGE_VERSION/rp-smartnode-install-$ARCH.tar.xz"
fi


# Create temporary data folder; clean up on exit
TEMPDIR=$(mktemp -d 2>/dev/null) || fail "Could not create temporary data directory."
trap 'rm -rf "$TEMPDIR"' EXIT


# Get temporary data paths
PACKAGE_FILES_PATH="$TEMPDIR/$ARCH/rp-smartnode-install"
NETWORK_FILES_PATH="$PACKAGE_FILES_PATH/network/$NETWORK"


##
# Installation
##


# OS dependencies
if [ -z "$NO_DEPS" ]; then
case "$PLATFORM" in

    # Ubuntu / Debian / Raspbian
    Ubuntu|Debian|Raspbian)

        # Get platform name
        PLATFORM_NAME=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')

        # Install OS dependencies
        progress 1 "Installing OS dependencies..."
        { sudo apt-get -y update || fail "Could not update OS package definitions."; } >&2
        { sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common chrony || fail "Could not install OS packages."; } >&2

        # Install docker
        progress 2 "Installing docker..."
        { curl -fsSL "https://download.docker.com/linux/$PLATFORM_NAME/gpg" | sudo apt-key add - || fail "Could not add docker repository key."; } >&2
        { sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$PLATFORM_NAME $(lsb_release -cs) stable" || fail "Could not add docker repository."; } >&2
        { sudo apt-get -y update || fail "Could not update OS package definitions."; } >&2
        { sudo apt-get -y install docker-ce docker-ce-cli containerd.io || fail "Could not install docker packages."; } >&2

        # Install docker-compose
        progress 3 "Installing docker-compose..."
        >&2 install_docker_compose

        # Add user to docker group
        progress 4 "Adding user to docker group..."
        >&2 add_user_docker

    ;;

    # Centos
    CentOS)

        # Install OS dependencies
        progress 1 "Installing OS dependencies..."
        { sudo yum install -y yum-utils chrony || fail "Could not install OS packages."; } >&2
        { sudo systemctl start chronyd || fail "Could not start chrony daemon."; } >&2

        # Install docker
        progress 2 "Installing docker..."
        { sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || fail "Could not add docker repository."; } >&2
        { sudo yum install -y --nobest docker-ce docker-ce-cli containerd.io || fail "Could not install docker packages."; } >&2
        { sudo systemctl start docker || fail "Could not start docker daemon."; } >&2

        # Install docker-compose
        progress 3 "Installing docker-compose..."
        >&2 install_docker_compose

        # Add user to docker group
        progress 4 "Adding user to docker group..."
        >&2 add_user_docker

    ;;

    # Fedora
    Fedora)

        # Install OS dependencies
        progress 1 "Installing OS dependencies..."
        { sudo dnf -y install dnf-plugins-core chrony || fail "Could not install OS packages."; } >&2
        { sudo systemctl start chronyd || fail "Could not start chrony daemon."; } >&2

        # Install docker
        progress 2 "Installing docker..."
        { sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || fail "Could not add docker repository."; } >&2
        { sudo dnf -y install docker-ce docker-ce-cli containerd.io || fail "Could not install docker packages."; } >&2
        { sudo systemctl start docker || fail "Could not start docker daemon."; } >&2
        { sudo systemctl enable docker || fail "Could not set docker daemon to auto-start on boot."; } >&2

        # Install docker-compose
        progress 3 "Installing docker-compose..."
        >&2 install_docker_compose

        # Add user to docker group
        progress 4 "Adding user to docker group..."
        >&2 add_user_docker

    ;;

    # Unsupported OS
    *)
        RED='\033[0;31m'
        echo ""
        echo -e "${RED}**ERROR**"
        echo "Automatic dependency installation for the $PLATFORM operating system is not supported."
        echo "Please install docker and docker-compose manually, then try again with the '-d' flag to skip OS dependency installation."
        echo "Be sure to add yourself to the docker group with 'sudo usermod -aG docker $USER' after installing docker."
        echo "Log out and back in, or restart your system after you run this command."
        exit 1
    ;;

esac
else
    echo "Skipping steps 1 - 4 (OS dependencies & docker)"
fi


# Create ~/.rocketpool dir & files
progress 5 "Creating Rocket Pool user data directory..."
{ mkdir -p "$RP_PATH/data/validators" || fail "Could not create the Rocket Pool user data directory."; } >&2
{ touch -a "$RP_PATH/settings.yml" || fail "Could not create the Rocket Pool user settings file."; } >&2


# Download and extract package files
progress 6 "Downloading Rocket Pool package files..."
{ curl -L "$PACKAGE_URL" | tar -xJ -C "$TEMPDIR" || fail "Could not download and extract the Rocket Pool package files."; } >&2
{ test -d "$PACKAGE_FILES_PATH" || fail "Could not extract the Rocket Pool package files."; } >&2


# Copy package files
progress 7 "Copying package files to Rocket Pool user data directory..."
{ test -d "$NETWORK_FILES_PATH" || fail "No package files were found for the selected network."; } >&2
{ cp -r "$NETWORK_FILES_PATH/"* "$RP_PATH" || fail "Could not copy network package files to the Rocket Pool user data directory."; } >&2
{ find "$RP_PATH/chains" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || fail "Could not set executable permissions on package files."; } >&2

}

install "$@"

