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

# Get and shift command name
COMMAND=$1
shift

# Run command
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
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" exec cli /go/bin/rocketpool-cli minipool stop "$MINIPOOL_IMAGE"
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" stop
        echo "Done! Run 'rocketpool start' to resume."

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
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" exec cli /go/bin/rocketpool-cli minipool stop "$MINIPOOL_IMAGE"
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" down -v --remove-orphans
        echo "Done! Run 'rocketpool start' to restart."
        echo "Your node data at $RP_PATH (including your node account and validator keychains) was not removed."

    ;;

    # Scale Rocket Pool services
    scale )
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" scale "$@"
    ;;

    # Configure Rocket Pool service stack
    config )

        # Confirm
        read -p "Are you sure you want to reconfigure the Rocket Pool services? They must be restarted for changes to take effect, and ethereum nodes may lose sync progress! (y/n) " -n 1 CONFIRM; echo
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            echo "Cancelling..."; exit 0
        fi

        # Configure
        source "$RP_PATH/docker/config.sh"
        echo "Done! Run 'rocketpool start' to restart with new settings in effect."
        
    ;;

    # View Rocket Pool service stack logs
    logs )
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" logs -f "$@"
    ;;

    # Display Rocket Pool service resource stats
    stats )
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" ps -q | xargs docker stats
    ;;

    # Run Rocket Pool CLI command
    run )
        docker-compose -f "$RP_PATH/docker/docker-compose.yml" --project-directory "$RP_PATH/docker" exec cli /go/bin/rocketpool-cli "$@"
    ;;

    # No command given - print info
    '' )
        echo "______           _        _    ______           _ "
        echo "| ___ \         | |      | |   | ___ \         | |"
        echo "| |_/ /___   ___| | _____| |_  | |_/ /__   ___ | |"
        echo "|    // _ \ / __| |/ / _ \ __| |  __/ _ \ / _ \| |"
        echo "| |\ \ (_) | (__|   <  __/ |_  | | | (_) | (_) | |"
        echo "\_| \_\___/ \___|_|\_\___|\__| \_|  \___/ \___/|_|"
        echo ""
        echo "Usage:"
        echo "  rocketpool start                       Initialise and start the Rocket Pool services"
        echo "  rocketpool pause                       Stop the Rocket Pool services without removing them"
        echo "  rocketpool stop                        Stop and remove the Rocket Pool services"
        echo "  rocketpool scale [SERVICE=NUM...]      Scale Rocket Pool service containers"
        echo "  rocketpool config                      Reconfigure the Rocket Pool services (requires restart)"
        echo "  rocketpool logs [SERVICES...]          View the current Rocket Pool service logs"
        echo "  rocketpool stats                       Display resource stats for running Rocket Pool services"
        echo "  rocketpool run [COMMAND] [ARGS...]     Run a specific Rocket Pool CLI command"
        echo ""
    ;;

    # Unrecognized command
    * )
        echo "The command '$COMMAND' is not recognized."
    ;;

esac
