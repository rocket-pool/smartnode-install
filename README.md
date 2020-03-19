# smartnode-install
The install script for a Rocket Pool smart node. This script must be run with admin access, use `sudo` or the equivalent command if required.

# Usage

Regular use:

`wget -Nnv https://github.com/rocket-pool/smartnode-install/releases/latest/download/install.sh && chmod +x ./install.sh && ./install.sh && rm -f install.sh`

Verbose mode:

`wget -Nnv https://github.com/rocket-pool/smartnode-install/releases/latest/download/install.sh && chmod +x ./install.sh && ./install.sh -v && rm -f install.sh`

Specific chain mode: (-n $chainId)

`wget -Nnv https://github.com/rocket-pool/smartnode-install/releases/latest/download/install.sh && chmod +x ./install.sh && ./install.sh -n 77 && rm -f install.sh`
