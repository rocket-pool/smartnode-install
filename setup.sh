##
# Intro
##

echo ""
echo "Welcome to the RocketPool Smart Node setup wizard!"
echo "This wizard is valid only for Ubuntu 16.04 and up. If you are using a different operating system, please cancel now."
echo "This script will install the following software on this computer:"
echo ""
echo "OS Packages:"
echo "- software-properties-common"
echo "- build-essential"
echo "- curl"
echo "- git"
echo "- nodejs"
echo "- your choice of the Geth or Parity ethereum clients"
echo ""
echo "NodeJS Packages:"
echo "- pm2"
echo "- pm2-server-monit"
echo ""
echo "RocketPool Software:"
echo "- rocketpool contract code repository (https://github.com/rocket-pool/rocketpool.git)"
echo "- rocketpool smart node daemon repository (https://github.com/rocket-pool/smartnode.git)"
echo ""
echo "* pm2 will also be configured to run smart node processes at system startup."
echo "* RocketPool software repositores will be stored in your home path."
echo "* Your ethereum client account password will be stored at ~/.smartnode/password with permissions of 'rw-------' (600)."
echo "  This will be used by the smart node daemon but will never be shared with RocketPool directly."
echo ""
echo "A notification email will be sent to RocketPool on completion."
echo "We will contact you once your node has been registered with the network with instructions to set up server monitoring."
echo ""
echo "This script will take several minutes to complete, please be patient."
echo "Press Control-C at any time to quit."
echo ""


##
# Parameters
##

echo ""
echo "Please answer the following questions about your Smart Node setup:"
echo ""

# Node software
echo "Which node software would you like to run?"
select NODESOFTWARE in "Geth" "Parity"; do
    echo "$NODESOFTWARE node software selected."; echo ""; break
done

# Node software account password
if [ -f ~/.smartnode/password ]; then
    NODEPASSWORD="$( cat ~/.smartnode/password )"
    echo "Account password file already exists."
    echo "using existing password '$NODEPASSWORD'."; echo ""
else
    read -p "Please enter your node account password: " NODEPASSWORD
    echo "Node account password '$NODEPASSWORD' entered."
    echo "Please record this password somewhere safe."; echo ""
fi

# Provider
echo "Please select your hosting provider:"
select PROVIDER in "AWS" "Rackspace"; do
    echo "$PROVIDER hosting provider selected."; echo ""; break
done

# Region
echo "Please select your hosting region:"
select REGIONID in "aus-east" "america-north"; do
    echo "$REGIONID hosting region selected."; echo ""; break
done

# Subnet
read -p "Please enter your server's subnet ID (eg 'NViginia', 'Ohio'): " SUBNETID
echo "Subnet ID '$SUBNETID' entered."; echo ""

# Instance ID
read -p "Please enter your server's instance ID (eg 'FA3422'): " INSTANCEID
echo "Instance ID '$INSTANCEID' entered."; echo ""

# Company name
read -p "Please enter your company name (optional; press Enter for none): " COMPANYNAME
if [ "$COMPANYNAME" != "" ]; then
    echo "Company name '$COMPANYNAME' entered."; echo ""
else
    echo "No company name entered."; echo ""
fi


##
# OS Dependencies
##

echo ""
echo "##########################"
echo "Installing OS Dependencies"
echo "##########################"
echo ""

# Update apt-get
sudo apt-get -y update
sudo apt-get -y upgrade

# Install OS dependencies
sudo apt-get -y install software-properties-common build-essential curl git

# Install NodeJS
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && sudo apt-get -y install nodejs


##
# Node Software
##

echo ""
echo "##########################"
echo "Setting Up Ethereum Client"
echo "##########################"
echo ""

# Save account password file
if [ ! -f ~/.smartnode/password ]; then
    mkdir ~/.smartnode
    chmod 700 ~/.smartnode
    touch ~/.smartnode/password
    chmod 600 ~/.smartnode/password
    echo "$NODEPASSWORD" > ~/.smartnode/password
fi

# Set up node software
case $NODESOFTWARE in

    # Geth
    Geth )
        
        # Install
        sudo add-apt-repository -y ppa:ethereum/ethereum
        sudo apt-get -y update
        sudo apt-get -y install ethereum

        # Create account and get address
        ACCOUNT="$( geth account new --password ~/.smartnode/password )"
        if [[ $ACCOUNT =~ ([a-fA-F0-9]{40}) ]] ; then
            ACCOUNTADDRESS="0x${BASH_REMATCH[1]}"
        else
            echo "Failed to get new Geth account address, exiting."; echo ""; exit
        fi

    ;;

    # Parity
    Parity )

        # Install
        curl https://get.parity.io -kL | sudo bash -s -- -r stable

        # Create account and get address
        ACCOUNT="$( parity account new --password ~/.smartnode/password )"
        if [[ $ACCOUNT =~ ([a-fA-F0-9]{40}) ]] ; then
            ACCOUNTADDRESS="0x${BASH_REMATCH[1]}"
        else
            echo "Failed to get new Parity account address, exiting."; echo ""; exit
        fi

    ;;

esac


##
# Javascript Dependencies
##

echo ""
echo "##############################"
echo "Installing NodeJS Dependencies"
echo "##############################"
echo ""

# Install NodeJS dependencies
sudo npm install -g pm2

# Install PM2 dependencies
sudo pm2 install pm2-server-monit

# Configure PM2 startup
PM2STARTUP="$( pm2 startup )"
if [[ $PM2STARTUP =~ (sudo .*$) ]] ; then
    PM2STARTUPCOMMAND="${BASH_REMATCH[1]}"
    eval $PM2STARTUPCOMMAND
    sudo chown -R ubuntu:ubuntu ~/.pm2
else
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!"
    echo "Failed to run PM2 startup command."
    echo "You will need to manually configure PM2 to run at system startup."
    echo "See http://pm2.keymetrics.io/docs/usage/startup/ for more information."
    echo "!!!!!!!!!!!!!!!!!!!!"
    echo ""
fi


##
# Clone Repositories
##

echo ""
echo "##############################"
echo "Installing RocketPool Software"
echo "##############################"
echo ""

# RocketPool
git clone https://github.com/rocket-pool/rocketpool.git ~/rocketpool

# Smart Node
# TODO: Currently displays SSH fingerprint prompt - switch to HTTPS once repo is public
git clone git@github.com:rocket-pool/smartnode.git ~/smartnode

# Set up RocketPool project
cd ~/rocketpool
npm install
cd -

# Set up Smart Node project
cd ~/smartnode
npm install
ln -s $HOME/rocketpool/build/contracts contracts
cd -


#################
## DEVELOPMENT ##
#################

echo ""
echo "##############################"
echo "Smart Node Setup (Development)"
echo "##############################"
echo ""

# Install truffle and ganache
sudo npm install -g truffle@v4.1.8
sudo npm install -g ganache-cli@v6.1.0

# Set up Smart Node project
if [ ! -f ~/smartnode/config/dev.json ]; then
read -r -d '' CONFIG << EOM
{
    "node": {
        "polling": {
            "connection": 5
        },
        "account": {
            "password": "$HOME/.smartnode/password"
        },
        "keystore": "$HOME/.ethereum/keystore",
        "type": "ganache"
    },
    "provider": "ws://127.0.0.1:8545",
    "logLevel": "info",
    "rocketPoolPath": "$HOME/rocketpool",
    "client": "ganache"
}
EOM
touch ~/smartnode/config/dev.json
echo "$CONFIG" > ~/smartnode/config/dev.json
fi

# Start Smart Node processes
cd ~/smartnode
pm2 start init.dev.config.js
cd -

# Save running processes
pm2 save


##
# Notify
##

echo ""
echo "####################"
echo "Sending Notification"
echo "####################"
echo ""

# Notification post data
read -r -d '' POSTDATA << EOM
{
    "nodeSoftware": "$NODESOFTWARE",
    "provider": "$PROVIDER",
    "regionId": "$REGIONID",
    "subnetId": "$SUBNETID",
    "instanceId": "$INSTANCEID",
    "companyName": "$COMPANYNAME",
    "accountAddress": "$ACCOUNTADDRESS"
}
EOM

# Send node setup notification
RESPONSE="$( curl -X POST -H "Content-Type: application/json" -H "Accept: application/json" -d "$POSTDATA" https://www.rocketpool.net/api/node/notify )"
if [[ $RESPONSE =~ success ]] ; then
    echo ""; echo "Successfully emailed node information."; echo ""
else
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!"
    echo "Failed to email node information."
    echo "Node setup notification response: $RESPONSE"
    echo "Please email dev@rocketpool.net to manually notify us of your node setup."
    echo "!!!!!!!!!!!!!!!!!!!!"
    echo ""
fi


##
# Cleanup
##

echo ""
echo "The RocketPool Smart Node setup wizard is now complete!"
echo "Your ethereum client account address is: $ACCOUNTADDRESS"
echo "Please record this somewhere safe. You will need to send funds to this address to cover node operation gas costs."
echo ""

