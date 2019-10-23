#!/bin/bash


##
# Config
##

echo $1;

exit 0;

# Smartnode installer github release version
# TODO: Make this pull down the 'latest' release automatically when we put out an official non-prelease (see here https://help.github.com/en/articles/linking-to-releases#linking-to-the-latest-release)
GITHUB_RELEASE="0.0.1"

# Path to install package
GITHUB_INSTALL_PACKAGE="file:///home/pi/Git/Ethereum/RocketPool/SmartNodeInstall/temp/smartnode-package.tar.xz"
# Path where to extract the package when it downloads
GITHUB_EXTRACT_DIR="/tmp/smartnode-install-$GITHUB_RELEASE";

## 
# OS ID and Ver
##

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

# Check to see if we have their OS ID
if [ -z "$OS_ID" ]; then
    echo "Warning: OS ID not detected. Installation may not work, would you like to continue anyway?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) break;;
            No ) exit;;
        esac
    done
fi

##
# Utils
##

# Get output streams (verbosity mode)
if [[ "$1" == "-v" ]]; then
    OUTPUTTO="/dev/stdout"
    PROGRESSTO="/dev/null"
else
    OUTPUTTO="/dev/null"
    PROGRESSTO="/dev/stdout"
fi

# Render progress bar
progress() {
    {

    # Get args
    COMPLETESTEPS=$1
    TOTALSTEPS=$2
    STEPSIZE=$3
    LABEL=$4

    # Clear line
    echo -ne "\033[K"

    # Render bar
    echo -n "  ["
    for (( S=0; S < $TOTALSTEPS; ++S )); do
        for (( C=0; C < $STEPSIZE; ++C )); do
            if [[ $S -lt $COMPLETESTEPS ]]; then echo -n "#"; else echo -n "-"; fi
        done
    done
    echo -n "]"

    # Render percentage
    COMPLETEPERCENT=$(($COMPLETESTEPS * 100 / $TOTALSTEPS))
    echo -n "  ($COMPLETEPERCENT%)"

    # Render label and return
    echo -n "  [$LABEL]"
    echo -ne "\r"

    } &> $PROGRESSTO
}

# Clear progress bar
clearprogress() {
    {
    echo -e "\033[K"
    } &> $PROGRESSTO
}


##
# Intro
##

echo ""
echo "**************************************************"
echo ""
echo "Welcome to the Rocket Pool Smart Node setup wizard!"
echo "This wizard is valid only for Ubuntu 16.04 and up. If you are using a different operating system, please cancel now."
echo "This script must be run as a user with root access. It will install the following software on this computer:"
echo ""
echo "OS Packages:"
echo "- apt-transport-https"
echo "- ca-certificates"
echo "- curl"
echo "- tar"
echo "- docker"
echo "- docker-compose"
echo "- gnupg-agent"
echo "- software-properties-common"
echo ""
echo "Rocket Pool Software:"
echo "- The Rocket Pool Smart Node service docker images"
echo "- The Rocket Pool CLI utility (at /usr/local/bin/rocketpool)"
echo ""
echo "* The RP_PATH environment variable will be added to your .profile and .bashrc files, and set to $HOME/.rocketpool."
echo "* Rocket Pool Smart Node data will be stored at RP_PATH."
echo "  This includes your node account and validator keystores. Do NOT modify or remove this data unless:"
echo "  - you have no ETH, rETH or RPL balance in your node account or node contract;"
echo "  - you will not be interacting with your node contract in future; and"
echo "  - your node has no minipools."
echo ""
echo "This script will take several minutes to complete, please be patient."
echo "Press Control-C at any time to quit."
echo ""
echo "**************************************************"
echo ""

# Prompt for root access
if ! sudo true; then
    echo "Please enter your password to proceed!"
    exit 1
fi


##
# Get the latest release
##

progress 0 4 6 "Downloading Smart Node Release"

{
echo ""
echo "##############################"
echo "Downloading Smart Node Release"
echo "##############################"
echo ""

# Install tar if it isn't already
sudo apt-get -y install tar

# Download and extract to temp dir
mkdir -p -m 755 "$GITHUB_EXTRACT_DIR" | curl -Ls "$GITHUB_INSTALL_PACKAGE" | tar -xJ -C "$GITHUB_EXTRACT_DIR"  | sudo chmod -R 755 "$GITHUB_EXTRACT_DIR"
# This is the main folder in the zip that should exist with the files
PACKAGE_DIR="$GITHUB_EXTRACT_DIR/smartnode-package"
# TODO: Remove
PACKAGE_DIR="./smartnode-package"

# The main folder of any OS specific files
PACKAGE_DIR_OS="$PACKAGE_DIR/install/os/$OS_ID"


# Check if our extracted dir exists with the package files and check the expected zip file dir exists
if [ ! -d "$PACKAGE_DIR_OS" ]; then
    echo "Warning: OS ID '$OS_ID' does not appear to be supported. Installation may not work, would you like to continue anyway?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) break;;
            No ) exit;;
        esac
    done
fi

} &> $OUTPUTTO

##
# OS Dependencies
##

progress 1 4 6 "Installing OS Dependencies"

{
echo ""
echo "##########################"
echo "Installing OS Dependencies"
echo "##########################"
echo ""


# Install common OS dependencies
#sudo apt-get -y update
# sudo apt-get -y upgrade TODO: Evaluate, might not be wise to update a servers packages automatically
#sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Install OS specific dependencies
if [ -d "$PACKAGE_DIR_OS" ] && [ -f "$PACKAGE_DIR_OS/dep.sh" ]; then
    source "$PACKAGE_DIR_OS/dep.sh"
fi

} &> $OUTPUTTO


##
# Rocket Pool software
##

progress 2 4 6 "Installing Rocket Pool Software"

{
echo ""
echo "###############################"
echo "Installing Rocket Pool Software"
echo "###############################"
echo ""

# Download smartnode docker images
docker pull rocketpool/smartnode-cli:v0.0.1
docker pull rocketpool/smartnode-minipool:v0.0.1
docker pull rocketpool/smartnode-minipools:v0.0.1
docker pull rocketpool/smartnode-node:v0.0.1
docker pull rocketpool/smartnode-watchtower:v0.0.1

# Copy CLI utility
sudo cp "$PACKAGE_DIR/files/bin/rocketpool.sh" /usr/local/bin/rocketpool
sudo chmod +x /usr/local/bin/rocketpool


} &> $OUTPUTTO


##
# Setup
##

progress 3 3 6 "Configuring Rocket Pool Services"

{
echo ""
echo "################################"
echo "Configuring Rocket Pool Services"
echo "################################"
echo ""

# Get and create Rocket Pool path
RP_PATH="$HOME/.rocketpool"
mkdir "$RP_PATH"
#mkdir "$RP_PATH/docker"
#mkdir "$RP_PATH/docker/setup"
#mkdir "$RP_PATH/docker/setup/pow"

# Add Rocket Pool path to .profile
if ! grep -Fq "export RP_PATH" "$HOME/.profile"; then
    echo "" >> "$HOME/.profile"
    echo "# Rocket Pool data" >> "$HOME/.profile"
    echo "export RP_PATH=\"$RP_PATH\"" >> "$HOME/.profile"
fi

# Add Rocket Pool path to .bashrc
if ! grep -Fq "export RP_PATH" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Rocket Pool data" >> "$HOME/.bashrc"
    echo "export RP_PATH=\"$RP_PATH\"" >> "$HOME/.bashrc"
fi

# Copy docker files
cp -R "$PACKAGE_DIR/files/rocketpool/*" RP_PATH

#cp "$PACKAGE_DIR/files/bin/rocketpool.sh"
#curl -L "https://github.com/rocket-pool/smartnode-install/releases/download/$GITHUB_RELEASE/docker-compose.yml"        -o "$RP_PATH/docker/docker-compose.yml"
#curl -L "https://github.com/rocket-pool/smartnode-install/releases/download/$GITHUB_RELEASE/docker-pow-start.sh"       -o "$RP_PATH/docker/setup/pow/start.sh"
#curl -L "https://github.com/rocket-pool/smartnode-install/releases/download/$GITHUB_RELEASE/docker-pow-genesis77.json" -o "$RP_PATH/docker/setup/pow/genesis77.json"
#chmod +x "$RP_PATH/docker/setup/pow/start.sh"

# Download node config
#curl -L "https://github.com/rocket-pool/smartnode-install/releases/download/$GITHUB_RELEASE/node-config.yml" -o "$RP_PATH/config.yml"

} &> $OUTPUTTO

# Complete progress bar
progress 4 4 6 "Complete!"
echo ""

# Run Rocket Pool config
echo ""
echo "Configuring Rocket Pool service options..."
source /usr/local/bin/rocketpool service config


##
# Cleanup
##

echo ""
echo "The Rocket Pool Smart Node setup wizard is now complete!"
echo "Please start a new terminal session and run 'rocketpool service start' to begin!"
echo ""

