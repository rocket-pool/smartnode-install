#!/bin/bash

# Rocket Pool CLI utility
# Performs operations which interact with the Rocket Pool service stack

# Check RP_PATH is set
if [ -z "$RP_PATH" ]; then
    echo "The RP_PATH environment variable is not set. If you've just installed Rocket Pool, please start a new terminal session and try again."
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
            echo "Starting Rocket Pool services..."
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" up -d
            echo "Done!"
        ;;

        # Pause Rocket Pool service stack
        pause )

            # Confirm
            read -p "Are you sure you want to pause the Rocket Pool services? Any staking minipools will be penalized! (y/n) " -n 1 CONFIRM; echo
            if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                echo "Cancelling..."; exit 0
            fi

            # Pause
            echo "Pausing Rocket Pool services..."
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker stop
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" stop
            echo "Done! Run 'rocketpool service start' to resume."

        ;;

        # Stop Rocket Pool service stack
        stop )

            # Confirm
            read -p "Are you sure you want to stop the Rocket Pool services? Any staking minipools will be penalized, and ethereum nodes will lose sync progress! (y/n) " -n 1 CONFIRM; echo
            if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                echo "Cancelling..."; exit 0
            fi

            # Stop
            echo "Removing Rocket Pool services..."
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker stop
            docker ps -aq --filter "ancestor=$MINIPOOL_IMAGE" | xargs docker rm
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" down -v --remove-orphans
            echo "Done! Run 'rocketpool service start' to restart."
            echo "Your node data at $RP_PATH (including your node account and validator keychains) was not removed."

        ;;

        # Scale Rocket Pool services
        scale )
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" scale "$@"
        ;;

        # Configure Rocket Pool service stack
        config )

            # Get docker .env file path
            DOCKERENV="$RP_PATH/docker/.env"

            # Confirm if docker .env file exists
            if [[ -f "$DOCKERENV" ]]; then
                read -p "Are you sure you want to reconfigure the Rocket Pool services? They must be restarted for changes to take effect, and ethereum nodes may lose sync progress! (y/n) " -n 1 CONFIRM; echo
                if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
                    echo "Cancelling..."; exit 0
                fi
            fi

            # Write docker config
            POW_BOOTNODES=(
                "enode://6114b79e7928bfb19ff8600bad6e09a49cfc53f7d9513bb0e854566102ee04bac8f494472bcc812211c2cc50684f8a04320d23c17410b52c6175e8246b5a3307@3.216.221.20:30305"
                "enode://80b8fe6fe4fe82761b2b40d57da58296d82f34f035b182cca411b9e55370f8c4f2734648523261b2be212352f3a218fa61f89517cf6abd005fb9acc27d289ff4@100.27.8.240:30303"
            )
            echo "COMPOSE_PROJECT_NAME=rocketpool" > "$DOCKERENV"
            echo "POW_CLIENT=geth" >> "$DOCKERENV"
            echo "POW_IMAGE=ethereum/client-go:latest" >> "$DOCKERENV"
            echo "POW_NETWORK_ID=77" >> "$DOCKERENV"
            echo "POW_BOOTNODE=${POW_BOOTNODES[0]},${POW_BOOTNODES[1]}" >> "$DOCKERENV"
            echo "POW_ETHSTATS_LABEL=RP2Beta-Node" >> "$DOCKERENV"
            echo "POW_ETHSTATS_LOGIN=rp2testbeta@3.216.221.20" >> "$DOCKERENV"

            # Log
            echo "Done! Run 'rocketpool service start' to start with new settings in effect."
            
        ;;

        # View Rocket Pool service stack logs
        logs )
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" logs -f "$@"
        ;;

        # Display Rocket Pool service resource stats
        stats )
            docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" ps -q | xargs docker stats
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
    if [[ ! $(docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" ps -q cli) ]]; then
        echo "The Rocket Pool service is not running. Please run 'rocketpool service start'."; exit 0
    fi

    # Run command
    docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" exec cli /go/bin/rocketpool-cli "$@"

fi
