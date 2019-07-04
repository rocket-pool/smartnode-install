#!/bin/bash


##
# Utils
##

# Get output streams (verbosity mode)
if [[ "$1" == "-v" ]] ; then
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
echo "This script must be run as a non-root user with root access. It will install the following software on this computer:"
echo ""
echo "OS Packages:"
echo "- apt-transport-https"
echo "- ca-certificates"
echo "- curl"
echo "- docker-ce"
echo "- docker-compose"
echo "- gnupg-agent"
echo "- software-properties-common"
echo ""
echo "Rocket Pool Software:"
echo "- The Rocket Pool Smart Node service docker images"
echo "- The Rocket Pool CLI utility (at /usr/local/bin/rocketpool)"
echo ""
echo "* The RP_PATH environment variable will be added to your bash profile and set to $HOME/.rocketpool."
echo "* Rocket Pool Smart Node data will be stored at RP_PATH."
echo "  This includes your node account and validator keystores. Do NOT modify or remove this data unless:"
echo "  - you have no ETH or RPL balance in your node account or node contract;"
echo "  - you will not be interacting with your node contract in future; and"
echo "  - your node has no minipools."
echo ""
echo "This script will take several minutes to complete, please be patient."
echo "Press Control-C at any time to quit."
echo ""
echo "**************************************************"
echo ""


##
# Parameters
##

echo ""
echo "Please answer the following questions about your Smart Node setup:"
echo ""; echo ""

# Ethereum client
echo "Which ethereum client would you like to run?"
select ETHCLIENT in "Geth" "Parity"; do
    echo "$ETHCLIENT ethereum client selected."; echo ""; echo ""; break
done

# Beacon chain client
echo "Which beacon chain client would you like to run?"
select BEACONCLIENT in "Prysm"; do
    echo "$BEACONCLIENT beacon chain client selected."; echo ""; echo ""; break
done


##
# OS Dependencies
##

progress 0 2 4 "Installing OS Dependencies"

{
echo ""
echo "##########################"
echo "Installing OS Dependencies"
echo "##########################"
echo ""

# Install OS dependencies
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -y update
sudo apt-get -y install docker-ce docker-compose

# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER

} &> $OUTPUTTO


##
# Rocket Pool software
##

progress 1 2 4 "Installing Rocket Pool Software"

{
echo ""
echo "###############################"
echo "Installing Rocket Pool Software"
echo "###############################"
echo ""

# Download docker images
docker pull rocketpool/smartnode-cli:latest
docker pull rocketpool/smartnode-node:latest
docker pull rocketpool/smartnode-minipools:latest
docker pull rocketpool/smartnode-minipool:latest
docker pull rocketpool/smartnode-watchtower:latest
docker pull rocketpool/beacon-chain-simulator:latest

# Download CLI utility
sudo curl https://raw.githubusercontent.com/rocket-pool/smartnode-install/master/scripts/rocketpool -o /usr/local/bin/rocketpool
sudo chmod 755 /usr/local/bin/rocketpool

} &> $OUTPUTTO


##
# Cleanup
##

progress 2 2 4 "Complete!"
echo ""

echo ""
echo "The Rocket Pool Smart Node setup wizard is now complete!"
echo "Please run 'rocketpool start' to begin!"
echo ""

