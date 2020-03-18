#!/bin/bash

# Rocket Pool CLI utility
# Performs operations which interact with the Rocket Pool service stack

# Check user
if [ $(id -u) -eq 0 ]; then
    echo "rocketpool should not be run as root, please try again without sudo."
    exit 1
fi

# Check RP_PATH is set
if [ -z "$RP_PATH" ]; then
    echo "The RP_PATH environment variable is not set. If you've just installed Rocket Pool, please start a new terminal session and try again."
    exit 1
fi

# Check docker files are found
if [[ ! -f "$RP_PATH/docker-compose.yml" ]]; then
    echo "docker-compose file not found! Please check your installation and try again."
    exit 1
fi
if [[ ! -f "$RP_PATH/.env" ]] && [[ "$1 $2" != "service config" ]]; then
    echo "docker .env file not found! Please run 'rocketpool service config' and try again."
    exit 1
fi

# Config
MINIPOOL_IMAGE="rocketpool/smartnode-minipool:v0.0.1"

# Run service commands
if [[ "$1" == "service" ]]; then

    # Get and shift subcommand name
    shift; COMMAND="$1"; shift

    # Run subcommand
    case $COMMAND in

        # Start Rocket Pool service stack
        start )

            # Log
            echo "Starting Rocket Pool services..."

            # Build up service stack
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" up -d

            # Copy OS timezone to CLI container
            TIMEZONE=$(cat /etc/timezone)
            if [ ! -z "$TIMEZONE" ]; then
                docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" exec cli /bin/sh -c "echo '$TIMEZONE' > /etc/timezone"
            fi

            # Log
            echo "Done!"

        ;;

        # Pause Rocket Pool service stack
        pause )

            # Confirm
            read -p "Are you sure you want to pause the Rocket Pool services? Any staking minipools will be penalized! (y/n) " -n 1 CONFIRM; echo
            if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                echo "Cancelling..."; exit 0
            fi

            # Log
            echo "Pausing Rocket Pool services..."

            # Stop service stack
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker stop 2>/dev/null
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" stop

            # Log
            echo "Done! Run 'rocketpool service start' to resume."

        ;;

        # Stop Rocket Pool service stack
        stop )

            # Confirm
            read -p "Are you sure you want to stop the Rocket Pool services? Any staking minipools will be penalized, and ethereum nodes will lose sync progress! (y/n) " -n 1 CONFIRM; echo
            if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                echo "Cancelling..."; exit 0
            fi

            # Log
            echo "Removing Rocket Pool services..."

            # Tear down service stack
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker stop 2>/dev/null
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker rm 2>/dev/null
            sleep 5
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" down -v --remove-orphans

            # Log
            echo "Done! Run 'rocketpool service start' to restart."
            echo "Your node data at $RP_PATH (including your node account and validator keychains) was not removed."

        ;;

        # Scale Rocket Pool services
        scale )

            # Log
            echo "Scaling Rocket Pool services..."

            # Scale services
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" scale "$@"

            # Log
            echo "Done!"

        ;;

        # Configure Rocket Pool service stack
        config )

            # Get docker .env file path
            DOCKERENV="$RP_PATH/.env"

            # Confirm if docker .env file exists
            if [[ -f "$DOCKERENV" ]]; then
                read -p "Are you sure you want to reconfigure the Rocket Pool services? They must be restarted for changes to take effect, and ethereum nodes may lose sync progress! (y/n) " -n 1 CONFIRM; echo
                if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                    echo "Cancelling..."; exit 0
                fi
            fi

            # Choose ethereum 1.0 client
            echo "Which ethereum 1.0 client would you like to run?"
            select ETH1CLIENT in "Geth"; do
                if [ -z "$ETH1CLIENT" ]; then
                    echo "Please select an option with the indicated number."
                else
                    echo "$ETH1CLIENT ethereum 1.0 client selected."; echo ""; break
                fi
            done

            # Choose ethereum 2.0 client
            echo "Which ethereum 2.0 client would you like to run?"
            select ETH2CLIENT in "Beacon Chain Simulator"; do
                if [ -z "$ETH2CLIENT" ]; then
                    echo "Please select an option with the indicated number."
                else
                    echo "$ETH2CLIENT ethereum 2.0 client selected."; echo ""; break
                fi
            done

            # Get ethereum client images
            case "$ETH1CLIENT" in
                Geth ) ETH1CLIENTIMAGE="ethereum/client-go:stable" ;;
            esac

            # Write docker config
            POW_BOOTNODES=(
                "enode://18710e76933eec5afa778744332cbf63b682fdca61d9c0c309b17c3c31ecaa21219dc952a347c76afef7fd201b55dfbcd7648cfdc4d23d34fc9840bdd0b00b71@3.93.71.84:30305"
                "enode://9c4b41bd2d3d7d790cbd661725e3797685ac67e6db71f8ae4324851a11784714f6f730e5125f09d71d9f3d65b759c17557da8a048611166fec82ec782dea72b6@3.93.71.84:30303"
            )
            echo "COMPOSE_PROJECT_NAME=rocketpool" > "$DOCKERENV"
            echo "POW_CLIENT=$ETH1CLIENT" >> "$DOCKERENV"
            echo "POW_IMAGE=$ETH1CLIENTIMAGE" >> "$DOCKERENV"
            echo "POW_NETWORK_ID=88" >> "$DOCKERENV"
            echo "POW_BOOTNODE=${POW_BOOTNODES[0]},${POW_BOOTNODES[1]}" >> "$DOCKERENV"
            echo "POW_ETHSTATS_LABEL=RP2Beta-Node" >> "$DOCKERENV"
            echo "POW_ETHSTATS_LOGIN=rp2betav1ethstats@3.216.221.20" >> "$DOCKERENV"
            echo "POW_INFURA_PROJECT_ID=$PROJECTID" >> "$DOCKERENV"

            # Log
            echo "Done! Run 'rocketpool service start' to start with new settings in effect."
            
        ;;

        # View Rocket Pool service stack logs
        logs )
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" logs -f "$@"
        ;;

        # Display Rocket Pool service resource stats
        stats )
            docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" ps -q | xargs docker stats
        ;;

        # No command given - print info
        '' )
            echo ""
            echo "______           _        _    ______           _ "
            echo "| ___ \         | |      | |   | ___ \         | |"
            echo "| |_/ /___   ___| | _____| |_  | |_/ /__   ___ | |"
            echo "|    // _ \ / __| |/ / _ \ __| |  __/ _ \ / _ \| |"
            echo "| |\ \ (_) | (__|   <  __/ |_  | | | (_) | (_) | |"
            echo "\_| \_\___/ \___|_|\_\___|\__| \_|  \___/ \___/|_|"
            echo ""
            echo "USAGE:"
            echo "   rocketpool service start                      Initialise and start the Rocket Pool services"
            echo "   rocketpool service pause                      Stop the Rocket Pool services without removing them"
            echo "   rocketpool service stop                       Stop and remove the Rocket Pool services"
            echo "   rocketpool service scale [SERVICE=NUM...]     Scale Rocket Pool service containers"
            echo "   rocketpool service config                     Reconfigure the Rocket Pool services (requires restart)"
            echo "   rocketpool service logs [SERVICES...]         View the current Rocket Pool service logs"
            echo "   rocketpool service stats                      Display resource stats for running Rocket Pool services"
            echo ""
        ;;

        # Unrecognized command
        * )
            echo "The command '$COMMAND' is not recognized."
        ;;

    esac

# Run CLI commands
else

    # Check CLI service is available
    if [[ ! $(docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" ps -q cli) ]]; then
        echo "The Rocket Pool service is not running. Please run 'rocketpool service start'."; exit 1
    fi

    # Run command with space around output
    echo ""; docker-compose -f "$RP_PATH/docker-compose.yml" --project-directory "$RP_PATH" exec cli /go/bin/rocketpool-cli "$@"; echo ""

fi
