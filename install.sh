#!/bin/bash

## RP core Installer script 
## Note: Any shell file with -exec.sh in the installer package will automatically have exec permissions added to it

# Prompt for root access
if ! sudo true; then
    echo "Please enter your password to proceed!"
    exit 1
fi


##
# OS and CPU
# -----------------------------------------------------------------------------
##


# Get CPU architecture
UNAME_VAL=$(uname -m)
ARCH=""
case $UNAME_VAL in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
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
# Defaults (can be overwritten by passing params)
# -----------------------------------------------------------------------------
##

# Current user executing sudo
USERNAME="$(logname)"
USEREXEC="sudo -u $USERNAME"
# Current home directory to use
USERHOMEDIR=$(eval echo "~$USERNAME")


# Default installer type
INSTALLER_TYPE='cli'
# Install dependencies
NO_DEPS=
# The Rocket Pool user data path
RP_PATH="$HOME/.rocketpool"
# The default smart node package version to download
PACKAGE_VERSION="latest"
# The default network to run Rocket Pool on
NETWORK="prater"
# Get genesis SSZ for the current network
NETWORK_GENESIS_URL="https://github.com/eth2-clients/eth2-networks/raw/master/shared/$NETWORK/genesis.ssz"
# The version of docker-compose to install
DOCKER_COMPOSE_VERSION="1.29.2"
# Progress output streams
OUTPUTTO="/dev/null"
PROGRESSTO="/dev/stdout"
# Temp dir to use (empty means make one later)
TEMPDIR=""


## 
# Parameters 
# -----------------------------------------------------------------------------
##

PARAMS=( $@ )
PARAMCOUNT=0

# Check what params have been passed
for i in "$@"
do
    # Get output streams (verbosity mode)
    if [[ "$i" == "-v" ]]; then
        OUTPUTTO="/dev/stdout"
        PROGRESSTO="/dev/null"
    fi
    # Check if this is being run by the GUI installer, if so we'll need to append some info for the steps
    if [[ "$i" == "-g" ]]; then
        INSTALLER_TYPE="gui"
        OUTPUTTO="/dev/null"
        PROGRESSTO="/dev/null"       
    fi
    # Home location to use
    if [[ "$i" == "-h" ]]; then
        # Get the user whos running sudo's home path
        USERHOMEDIR=${PARAMS[$((PARAMCOUNT+1))]}
    fi
    # Package release version to download - Should be passed '-p 0.0.1' etc
    if [[ "$i" == "-p" ]]; then
        # Get the version
        GITPACKAGEVER=${PARAMS[$((PARAMCOUNT+1))]}
    fi
    # Network ID to use - Should be passed '-n 77' etc
    if [[ "$i" == "-n" ]]; then
        # Get the version
        NETWORK_ID=${PARAMS[$((PARAMCOUNT+1))]}
    fi
    # Temp dir to unpack the files to (optional, one will be created if not passed). Should be passed '-t $TEMPDIRlocation'
    if [[ "$i" == "-t" ]]; then
        # Get the path
        TEMPDIR=${PARAMS[$((PARAMCOUNT+1))]}
    fi
    # Install dependencies
    if [[ "$i" == "-d" ]]; then
        NO_DEPS=true;
    fi
    # Count the param number
    PARAMCOUNT=$((PARAMCOUNT+1))
done

## Create temp dir to extract files to if one hasn't been passed
if [ -z "$TEMPDIR" ]; then
    TEMPDIR=$($USEREXEC mktemp -d 2>/dev/null || $USEREXEC mktemp -d -t 'mytmpdir' || fail 'Could not create a temporary directory')
fi

# Check temp dir exists
test -d "$TEMPDIR" || fail "Temporary directory does not exist @ $TEMPDIR"

# Get temporary data paths
PACKAGE_FILES_PATH="$TEMPDIR/rp-smartnode-install"
NETWORK_FILES_PATH="$PACKAGE_FILES_PATH/network/$NETWORK"

# Get and create Rocket Pool path
RP_PATH="$USERHOMEDIR/.rocketpool"


## 
# Utils
# -----------------------------------------------------------------------------
##

# Print a failure message to stderr and exit
fail() {
    MESSAGE=$1
    RED='\033[0;31m'
    >&2 echo -e "\n${RED}**ERROR**\n$MESSAGE"
    exit 1
}


# Render progress bar
function progress() {
    {
    # Get args
    COMPLETESTEPS=$1
    TOTALSTEPS=$2
    STEPSIZE=$3
    LABEL=$4

    # Clear line
    echo -ne "\033[K"

    # Render bar
    echo -n "["
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
function clearprogress() {
    {
    echo -e "\033[K"
    } &> $PROGRESSTO
}



## 
# Initialise and base settings
# -----------------------------------------------------------------------------
##

# Get package files URL
if [ "$PACKAGE_VERSION" = "latest" ]; then
    PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/latest/download/rp-smartnode-install-$ARCH.tar.xz"
else
    # Check the version for backwards compatibility
    RP_VERSION=$(echo "$PACKAGE_VERSION" | rev | cut -d "." -f1 | rev)
    if [ $RP_VERSION -ge 4 ]; then
        # Modern version
        PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/download/$PACKAGE_VERSION/rp-smartnode-install-$ARCH.tar.xz"
    else
        # Legacy version
        if [ "$ARCH" = "amd64" ]; then
            PACKAGE_URL="https://github.com/rocket-pool/smartnode-install/releases/download/$PACKAGE_VERSION/rp-smartnode-install.tar.xz"
        else
            fail "This version does not support arm64 systems."
        fi
    fi
fi


# 
# Our installing steps and commands
# -----------------------------------------------------------------------------
##

## Create our step array - each line is delimited with a desc*command
declare -a CORECMDS

## Verify the users home dir exists
CORECMDS+=("Verifying User Home Dir Exists@test -n '$USERHOMEDIR' && test -d '$USERHOMEDIR' || fail 'User home directory does not exist at $USERHOMEDIR.'")

# Docker installation steps
install_docker_compose() {
    if [ $ARCH = "amd64" ]; then
        CORECMDS+=("Docker Compose: Downloading...@sudo curl -L 'https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose || fail 'Could not download docker-compose'")
        CORECMDS+=("Docker Compose: Downloading...@sudo chmod a+x /usr/local/bin/docker-compose || fail 'Could not set executable permissions on docker-compose'")
    elif [ $ARCH = "arm64" ]; then
        if command -v apt &> /dev/null ; then
            CORECMDS+=("Docker Compose ARM: Installing dependencies@sudo apt install -y libffi-dev libssl-dev python3 python3-pip && sudo apt remove -y python-configparser || fail 'Could not install docker compose ARM dependencies'")
            CORECMDS+=("Docker Compose ARM: Installing...@sudo pip3 install docker-compose || fail 'Could not install docker compose ARM'")
        else
            RED='\033[0;31m'
            echo ""
            echo -e "${RED}**ERROR**"
            echo "Automatic installation of docker-compose for the $PLATFORM operating system on ARM64 is not currently supported."
            echo "Please install docker-compose manually, then try this again with the '-d' flag to skip OS dependency installation."
            echo "Be sure to add yourself to the docker group (e.g. 'sudo usermod -aG docker $USERNAME') after installing docker."
            echo "Log out and back in, or restart your system after you run this command."
            exit 1
        fi
    fi
}

# Add user to docker group
add_user_docker() {
    CORECMDS+=("Docker Compose: Adding user to group@sudo usermod -aG docker $USERNAME || fail 'Could not add user $USERNAME to docker group.'")
}


# Install dependencies
if [ -z "$NO_DEPS" ]; then
    case "$PLATFORM" in

    # Ubuntu / Debian / Raspbian
    Ubuntu|Debian|Raspbian)

        # Get platform name
        PLATFORM_NAME=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')

        # Install OS dependencies
        CORECMDS+=("OS: Updating $PLATFORM_NAME OS package definitions@sudo apt-get -y update || fail 'Could not update OS package definitions'")
        CORECMDS+=("OS: Installing $PLATFORM_NAME OS packages@sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common ntp || fail 'Could not install OS packages'")

        # Install docker
        CORECMDS+=("Docker: Adding repository key@curl -fsSL 'https://download.docker.com/linux/$PLATFORM_NAME/gpg' | sudo apt-key add - || fail 'Could not add docker repository key'")
        CORECMDS+=("Docker: Adding repository@sudo add-apt-repository 'deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$PLATFORM_NAME $(lsb_release -cs) stable' || fail 'Could not add docker repository'")
        CORECMDS+=("Docker: Updating $PLATFORM_NAME OS package definitions@sudo apt-get -y update || fail 'Could not update OS package definitions'")
        CORECMDS+=("Docker: Installing required packages@sudo apt-get -y install docker-ce docker-ce-cli containerd.io || fail 'Could not install docker packages'")

        # Install docker-compose
        install_docker_compose

        # Add user to docker group
        add_user_docker

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
        echo "Be sure to add yourself to the docker group with 'sudo usermod -aG docker $USERNAME' after installing docker."
        echo "Log out and back in, or restart your system after you run this command."
        exit 1
    ;;

esac
else
    echo "Skipping steps 1 - 4 (OS dependencies & docker)"
fi





## 
# Core Install Run
##

# Intro 
if [[ "$INSTALLER_TYPE" == "cli" ]]; then
    echo "______           _        _    ______           _"
    echo "| ___ \\         | |      | |   | ___ \\         | |"
    echo "| |_/ /___   ___| | _____| |_  | |_/ /__   ___ | |"
    echo "|    // _ \\ / __| |/ / _ \\ __| |  __/ _ \\ / _ \\| |"
    echo "| |\\ \\ (_) | (__|   <  __/ |_  | | | (_) | (_) | |"
    echo "\\_| \\_\\___/ \\___|_|\\_\\___|\\__| \\_|  \\___/ \\___/|_|"
    echo ""
    echo "**************************************************"
    echo ""
    echo "Welcome to the Rocket Pool Smart Node setup wizard!"
    echo ""
    echo "This wizard is currently available for platforms Ubuntu, Debian, CentOS, Fedora and Raspbian."
    echo "This script must be run as a user with root access. It will install the following software on this computer:"
    echo ""
    echo "Common Packages:"
    echo "- apt-transport-https, ca-certificates, tar, docker, docker-compose, gnupg-agent, software-properties-common"
    echo ""
    echo "Rocket Pool Software:"
    echo "- The Rocket Pool Smart Node service docker images"
    echo "- The Rocket Pool CLI utility (at ~/bin/rocketpool)"
    echo ""
    echo "* The RP_PATH environment variable will be added to your .profile and .bashrc files, and set to $USERHOMEDIR/.rocketpool."
    echo "* Rocket Pool Smart Node data will be stored at $RP_PATH."
    echo "  This includes your node account and validator keystores. Do NOT modify or remove this data unless:"
    echo "  - you have no ETH, rETH or RPL balance in your node account or node contract;"
    echo "  - you will not be interacting with your node contract in future; and"
    echo "  - your node has no minipools."
    echo ""
    echo "This script will take several minutes to complete, please be patient."
    echo ""
    echo "Press Control-C at any time to quit."
    echo ""
    echo "**************************************************"
    echo ""
fi



## The current step
CORESTEPCURRENT=1;

# Get the total number of steps
CORESTEPTOTAL=${#CORECMDS[@]}

# for loop that iterates over each element in arr
for STEP in "${CORECMDS[@]}"
do
    ## Get the main step items
    IFS='@'
    read -ra line <<< "$STEP" 
    ## The step parts
    CORESTEPDESC=${line[0]}
    ## Multiple commands in this step can be seperated with &&
    CORESTEPCOMMANDS=${line[1]}     
    ## Echo the line in a delimited format for the GUI
    if [[ "$INSTALLER_TYPE" == "gui" ]]; then
        echo "CORE|$CORESTEPTOTAL|$CORESTEPCURRENT|$CORESTEPDESC"
        ## Small delay between each so the any watcher doesn't miss really super quick commands (eg GUI)
        sleep 0.25s
    else
        progress $CORESTEPCURRENT $CORESTEPTOTAL 2 $CORESTEPDESC
        {
            echo ""
            echo "#####################################"
            echo $CORESTEPDESC
            echo "#####################################"
            echo ""
        } &> $OUTPUTTO
    fi
    ## Run the current commands
    #echo "$CORESTEPCOMMANDS"
    eval "$CORESTEPCOMMANDS" &> $OUTPUTTO
    ## Count the steps
    CORESTEPCURRENT=$((CORESTEPCURRENT+1))
done


# Outro 
if [[ "$INSTALLER_TYPE" == "cli" ]]; then

    # Running 'rocketpool' for the first time should run the config generator (client select etc)
    echo ""
    echo ""
    echo "The Rocket Pool Smart Node install wizard is now complete!"
    echo ""
    echo "Please start a new terminal session and run 'rocketpool' to begin!"
    echo ""
fi

exit 0