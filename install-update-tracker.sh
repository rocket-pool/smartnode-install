#!/bin/sh

# This script sets up the OS update and Rocket Pool update collector, along with
# integration with Prometheus's node-exporter and auto-running during apt or dnf
# executions.


# The path that the node exporter will be configured to look for textfiles in
TEXTFILE_COLLECTOR_PATH="/var/lib/node_exporter/textfile_collector"
UPDATE_SCRIPT_PATH="/usr/share"


# Print a failure message to stderr and exit
fail() {
    MESSAGE=$1
    >&2 echo -e "\n${COLOR_RED}**ERROR**\n$MESSAGE${COLOR_RESET}"
    exit 1
}


# Get the platform type
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Linux" ]; then

    # Check for /etc/os-release
    if [ -f /etc/os-release ]; then
        OS_ID=$(awk -F= '/^ID/{print $2}' /etc/os-release)
        if [ $(echo $OS_ID | grep -c -E "ubuntu|debian|linuxmint") -gt "0" ]; then
            INSTALLER="apt"
        elif [ $(echo $OS_ID | grep -c -E "fedora|rhel|centos") -gt "0" ]; then
            INSTALLER="dnf"
        fi

    # Fall back to `lsb_release`
    elif command -v lsb_release &>/dev/null ; then
        OS_ID=$(lsb_release -si)
        if [ $(echo $OS_ID | grep -c -E "ubuntu|debian|linuxmint") -gt "0" ]; then
            INSTALLER="apt"
        elif [ $(echo $OS_ID | grep -c -E "fedora|rhel|centos") -gt "0" ]; then
            INSTALLER="dnf"
        fi

    # Fall back to others
    elif [ -f "/etc/centos-release" ]; then
        INSTALLER="dnf"
    elif [ -f "/etc/fedora-release" ]; then
        INSTALLER="dnf"
    fi
    
fi


# The default smart node package version to download
PACKAGE_VERSION="latest"


# Print progress
progress() {
    STEP_NUMBER=$1
    MESSAGE=$2
    echo "Step $STEP_NUMBER of $TOTAL_STEPS: $MESSAGE"
}


# Install
install() {


# Parse arguments
while getopts "v:" FLAG; do
    case "$FLAG" in
        v) PACKAGE_VERSION="$OPTARG" ;;
        *) fail "Incorrect usage." ;;
    esac
done


# Get package files URL
if [ "$PACKAGE_VERSION" = "latest" ]; then
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/latest/download/rp-update-tracker.tar.xz"
else
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/download/$PACKAGE_VERSION/rp-update-tracker.tar.xz"
fi


# Create temporary data folder; clean up on exit
TEMPDIR=$(mktemp -d 2>/dev/null) || fail "Could not create temporary data directory."
trap 'rm -rf "$TEMPDIR"' EXIT


# Get temporary data paths
PACKAGE_FILES_PATH="$TEMPDIR/rp-update-tracker"
NETWORK_FILES_PATH="$PACKAGE_FILES_PATH/network/$NETWORK"


case "$INSTALLER" in

    # Distros using apt
    apt)

        # The total number of steps in the installation process
        TOTAL_STEPS="3"
        
        # Install dependencies 
        progress 1 "Installing dependencies..."
        { sudo apt -y update || fail "Could not update OS package definitions."; } >&2
        { sudo apt -y install update-notifier-common moreutils || fail "Could not install OS dependencies.";  } >&2

        # Download and extract package files
        progress 2 "Downloading Rocket Pool update tracker package files..."
        { curl -L "$PACKAGE_URL" | tar -xJ -C "$TEMPDIR" || fail "Could not download and extract the Rocket Pool update tracker package files."; } >&2
        { test -d "$PACKAGE_FILES_PATH" || fail "Could not extract the Rocket Pool update tracker package files."; } >&2

        # Install the update tracker files
        progress 3 "Installing update tracker..."
        { sudo mkdir -p "$TEXTFILE_COLLECTOR_PATH" || fail "Could not create textfile collector path."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/apt/apt-metrics.sh" "$UPDATE_SCRIPT_PATH" || fail "Could not move apt update collector."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/rp-version-check.sh" "$UPDATE_SCRIPT_PATH" || fail "Could not move Rocket Pool update collector."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/apt/apt-prometheus-metrics" "/etc/apt/apt.conf.d/60prometheus-metrics" || fail "Could not move apt trigger."; } >&2
        { sudo chmod +x "$UPDATE_SCRIPT_PATH/apt-metrics.sh" || fail "Could not set permissions on apt update collector."; } >&2
        { sudo chmod +x "$UPDATE_SCRIPT_PATH/rp-version-check.sh" || fail "Could not set permissions on Rocket Pool update collector."; } >&2

    ;;

    # Distros using dnf
    dnf)

        # The total number of steps in the installation process
        TOTAL_STEPS="4"

        # Install dependencies
        progress 1 "Installing dependencies..."
        { sudo dnf -y check-update || fail "Could not update OS package definitions."; } >&2
        { sudo dnf -y install dnf-utils moreutils || fail "Could not install OS dependencies.";  } >&2

        # Download and extract package files
        progress 2 "Downloading Rocket Pool update tracker package files..."
        { curl -L "$PACKAGE_URL" | tar -xJ -C "$TEMPDIR" || fail "Could not download and extract the Rocket Pool update tracker package files."; } >&2
        { test -d "$PACKAGE_FILES_PATH" || fail "Could not extract the Rocket Pool update tracker package files."; } >&2

        # Install the update tracker files
        progress 3 "Installing update tracker..."
        { sudo mkdir -p "$TEXTFILE_COLLECTOR_PATH" || fail "Could not create textfile collector path."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/dnf/dnf-metrics.sh" "$UPDATE_SCRIPT_PATH" || fail "Could not move dnf update collector."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/rp-version-check.sh" "$UPDATE_SCRIPT_PATH" || fail "Could not move Rocket Pool update collector."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/dnf/rp-dnf-check.sh" "$UPDATE_SCRIPT_PATH" || fail "Could not move update tracker script."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/dnf/rp-update-tracker.service" "/etc/systemd/system" || fail "Could not move update tracker service."; } >&2
        { sudo mv "$PACKAGE_FILES_PATH/dnf/rp-update-tracker.timer" "/etc/systemd/system" || fail "Could not move update tracker timer."; } >&2
        { sudo chmod +x "$UPDATE_SCRIPT_PATH/dnf-metrics.sh" || fail "Could not set permissions on dnf update collector."; } >&2
        { sudo chmod +x "$UPDATE_SCRIPT_PATH/rp-version-check.sh" || fail "Could not set permissions on Rocket Pool update collector."; } >&2
        { sudo chmod +x "$UPDATE_SCRIPT_PATH/rp-dnf-check.sh" || fail "Could not set permissions on Rocket Pool update tracker script."; } >&2

        # Install the update checking service
        progress 4 "Installing update tracker service..."
        { sudo systemctl daemon-reload || fail "Couldn't update systemctl daemons."; } >&2
        { sudo systemctl enable rp-update-tracker || fail "Couldn't enable update tracker service."; } >&2
        { sudo systemctl start rp-update-tracker || fail "Couldn't start update tracker service."; } >&2

    ;;

    # Unsupported package manager
    *)
        RED='\033[0;31m'
        echo ""
        echo -e "${RED}**ERROR**"
        echo "Update tracker installation is only supported for system that use the 'apt' or 'dnf' package managers."
        echo "If your operating system uses one of these and you received this message in error, please notify the Rocket Pool team."
        exit 1
    ;;

}

install "$@"
