#!/bin/bash

## RP core Installer script 
## Note: Any shell file with -exec.sh in the installer package will automatically have exec permissions added to it


function fail {
    printf '%s\n' "$1" >&2  ## Send message to stderr. Exclude >&2 if you don't want it that way.
    exit "${2-1}"           ## Return a code specified by $2 or 1 by default.
}

# Prompt for root access
if ! sudo true; then
    echo "Please enter your password to proceed!"
    exit 1
fi


##
# Defaults (can be overwritten by passing params)
##

# Default installer type
INSTALLER_TYPE='cli'
# Default network ID
NETWORK_ID='77'
# Progress output streams
OUTPUTTO="/dev/null"
PROGRESSTO="/dev/stdout"
# The version to download - 'latest' will automatically download the latest release
GITPACKAGEVER="latest"
# Current user executing sudo
USERNAME="$(logname)"
USEREXEC="sudo -u $USERNAME"
# Current home directory to use
USERHOMEDIR=$(eval echo "~$USERNAME")
# Temp dir to use (empty means make one later)
TEMPDIR=""


## 
# Parameters 
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
    # Temp dir to unpack the files too (optional, one will be created if not passed). Should be passed '-t $TEMPDIRlocation'
    if [[ "$i" == "-t" ]]; then
        # Get the path
        TEMPDIR=${PARAMS[$((PARAMCOUNT+1))]}
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

# Set the location of the files in the temp dir
TEMPFILESDIR="$TEMPDIR/rp-smartnode-install"


## Create the URL to download the package from TODO: Chnage to live github
INSTALL_URL="https://github.com/rocket-pool/smartnode-install/releases/latest/download/rp-smartnode-install.tar.xz"
#INSTALL_URL="http://192.168.0.100:8080/share.cgi?ssid=02f6eTL&fid=02f6eTL&path=%2F&filename=rp-smartnode-install.tar.xz&openfolder=forcedownload&ep="


## 
# Utils
##

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
##

# Get and create Rocket Pool path
RP_PATH="$USERHOMEDIR/.rocketpool"


# PLATFORM ID and VER
PLATFORM_ID=$(uname -s)
PLATFORM_OS_VER=''
# If it's Linux, check which flavour
if [[ "$PLATFORM_ID" == "Linux" ]]; then
    PLATFORM_OS_VER=$(lsb_release -si)
fi


# 
# Our installing steps and commands
##

## Create our step array - each line is delimited with a desc*command
declare -a CORECMDS

## Verify the users home dir exists
CORECMDS+=("Verifying User Home Dir Exists@test -n '$USERHOMEDIR' && test -d '$USERHOMEDIR' || fail 'User home directory does not exist at $USERHOMEDIR.'")

## Download smartnode package as the user
CORECMDS+=("Downloading Smartnode Package: $GITPACKAGEVER@wget -qO- '$INSTALL_URL' | tar -xJ -C '$TEMPDIR' || fail 'Could not download smartnode package'")

## Set ownership and perms (set to executable for directories and normal for files) on the files to the current user (they need to be extracted as root)
CORECMDS+=("Updating file ownership@chmod -R u+rwX,go+rX,go-w $TEMPDIR && chown -R $USERNAME: $TEMPDIR || fail 'Could not update temp file owner to $USERNAME'")

## Check this network ID is supported
CORECMDS+=("Verifying Support for Network ID: $NETWORK_ID@$USEREXEC test -d '$TEMPFILESDIR/files/rocketpool/network/$NETWORK_ID' || fail 'Network ID $NETWORK_ID not currently supported. $TEMPFILESDIR'")

## Check this platform is supported
CORECMDS+=("Verifying Support for Platform: $PLATFORM_ID@$USEREXEC test -d '$TEMPFILESDIR/install/platform/$PLATFORM_ID' || fail 'Platform $PLATFORM_ID not currently supported, sorry :('")

## Install any dependencies just for this platform if they exist
if [ -f "$TEMPDIR/install/platform/$PLATFORM_ID/dep.sh" ]; then 
    CORECMDS+=("Installing $PLATFORM_ID OS Specific Dependencies@source '$TEMPFILESDIR/install/platform/$PLATFORM_ID/dep.sh' || fail 'Could not install specific platform dependencies'")
fi

## Check this platform OS is supported if it'splatform is and install specific dependencies if they do
if [ ! -z "$PLATFORM_OS_VER" ]; then
    CORECMDS+=("Verifying Support for $PLATFORM_ID OS $PLATFORM_OS_VER@$USEREXEC test -d '$TEMPFILESDIR/install/platform/$PLATFORM_ID/$PLATFORM_OS_VER' || fail '$PLATFORM_ID OS $PLATFORM_OS_VER not currently supported, sorry :('")
    CORECMDS+=("Installing $PLATFORM_ID OS $PLATFORM_OS_VER Specific Dependencies@source '$TEMPFILESDIR/install/platform/$PLATFORM_ID/$PLATFORM_OS_VER/dep.sh' &> $OUTPUTTO || fail 'Could not install specific platform dependencies'")
fi

# Create a users settings.yml file if it doesn't exist. This file overwrites parameters in the master config.yml
CORECMDS+=("Creating Rocket Pool User Directory@mkdir -p $RP_PATH || fail 'Could create Rocket Pool user directory'")

# Create a users settings.yml file if it doesn't exist. This file overwrites parameters in the master config.yml
CORECMDS+=("Creating User Settings File@touch -a $RP_PATH/settings.yml || fail 'Could create user settings file at $RP_PATH/settings.yml'")

# Copy RP docker files for the desired network
CORECMDS+=("Copying Shared Rocket Pool Assets@$USEREXEC cp -R '$TEMPFILESDIR/files/rocketpool/shared/.' $RP_PATH || fail 'Could not add shared Rocket Pool files to Rocket Pool path'")
CORECMDS+=("Copying ETH Network Config@$USEREXEC cp -R '$TEMPFILESDIR/files/rocketpool/network/$NETWORK_ID/.' $RP_PATH || fail 'Could not add ETH Network files to Rocket Pool path'")

# Add Rocket Pool path to .profile
if ! grep -Fq "export RP_PATH" "$USERHOMEDIR/.profile"; then
    CORECMDS+=("Adding Rocket Pool Path to .profile@echo '' >> '$USERHOMEDIR/.profile' && echo '# Rocket Pool data' >> '$USERHOMEDIR/.profile' && echo 'export RP_PATH=\"$RP_PATH\"' >> '$USERHOMEDIR/.profile'  || fail 'Could not add Rocket Pool path to $USERHOMEDIR/.profile'")
fi

# Add Rocket Pool path to .bashrc
if ! grep -Fq "export RP_PATH" "$USERHOMEDIR/.bashrc"; then
    CORECMDS+=("Adding Rocket Pool Path to .bashrc@echo '' >> '$USERHOMEDIR/.bashrc' && echo '# Rocket Pool data' >> '$USERHOMEDIR/.bashrc' && echo 'export RP_PATH=\"$RP_PATH\"' >> '$USERHOMEDIR/.bashrc'  || fail 'Could not add Rocket Pool path to $USERHOMEDIR/.bashrc'")
fi

# Set permissions on exec files for this network
CORECMDS+=("Setting file permissions@sudo find '$RP_PATH' -maxdepth 8 -name '*-exec.sh' -exec chmod +x {} + || fail 'Could not set permissions on executable shell scripts'")

## Install any dependencies just for this platform OS if they exist
CORECMDS+=("Installing Rocket Pool - CLI@docker pull rocketpool/smartnode-cli:v0.0.1 &> $OUTPUTTO || fail 'Could not install Rocket Pool docker component - CLI'")
CORECMDS+=("Installing Rocket Pool - Minipool@docker pull rocketpool/smartnode-minipool:v0.0.1 &> $OUTPUTTO || fail 'Could not install Rocket Pool docker component - Minipool'")
CORECMDS+=("Installing Rocket Pool - Minipool Manager@docker pull rocketpool/smartnode-minipools:v0.0.1 &> $OUTPUTTO || fail 'Could not install Rocket Pool docker component - Minipools'")
CORECMDS+=("Installing Rocket Pool - Watchtower@docker pull rocketpool/smartnode-watchtower:v0.0.1 &> $OUTPUTTO || fail 'Could not install Rocket Pool docker component - Watchtower'")
CORECMDS+=("Installing Rocket Pool - Node@docker pull rocketpool/smartnode-node:v0.0.1 &> $OUTPUTTO || fail 'Could not install Rocket Pool docker component - Node'")

# Check the users ~/bin dir exists, if not create it
if [ ! -d "$USERHOMEDIR/bin" ]; then
    CORECMDS+=("Creating Local Bin Directory@mkdir -p '$USERHOMEDIR/bin' && chown -R $USERNAME: '$USERHOMEDIR/bin' || fail 'Could not create local user bin directory'")
fi

# Copy CLI utility (this is done last as the GUI checks for its existance when seeing if RP was installed fully)
CORECMDS+=("Copying Rocket Pool Bin@cp '$TEMPFILESDIR/files/bin/rocketpool.sh' '$USERHOMEDIR/bin/rocketpool' && sudo chmod +x '$USERHOMEDIR/bin/rocketpool' || fail 'Could not copy Rocket Pool bin too $USERHOMEDIR/bin'")


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
    echo "This wizard is currently valid only for Ubuntu 16.04 and up. If you are using a different operating system, please cancel now."
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
    eval "$CORESTEPCOMMANDS" 
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
