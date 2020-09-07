# smartnode-install

This repository contains compiled binaries for the [Rocket Pool smart node](https://github.com/rocket-pool/smartnode) client, as well as the installation script & configuration assets for the smart node service.

The smart node client is supported on Linux, MacOS and Windows.
Note that a smart node cannot be run locally on Windows at this stage; the Windows client can only be used to manage a remote server.

The smart node service is supported on all Unix platforms, with automatic dependency installation for Ubuntu, Debian, CentOS and Fedora.
A smart node can be run on other Unix platforms, but manual installation of dependencies (docker and docker-compose) is required.


## Smart Node Client Installation

### Linux

With cURL:
```
curl -L https://github.com/rocket-pool/smartnode-install/releases/latest/download/rocketpool-cli-linux-amd64 -o /usr/local/bin/rocketpool
chmod u+x /usr/local/bin/rocketpool
```

With wget:
```
wget https://github.com/rocket-pool/smartnode-install/releases/latest/download/rocketpool-cli-linux-amd64 -O /usr/local/bin/rocketpool
chmod u+x /usr/local/bin/rocketpool
```

### MacOS

With cURL:
```
curl -L https://github.com/rocket-pool/smartnode-install/releases/latest/download/rocketpool-cli-darwin-amd64 -o /usr/local/bin/rocketpool
chmod u+x /usr/local/bin/rocketpool
```

With wget:
```
wget https://github.com/rocket-pool/smartnode-install/releases/latest/download/rocketpool-cli-darwin-amd64 -O /usr/local/bin/rocketpool
chmod u+x /usr/local/bin/rocketpool
```

### Windows

1. Download from `https://github.com/rocket-pool/smartnode-install/releases/latest/download/rocketpool-cli-windows-amd64.exe`
2. Move to desired location


## Smart Node Service Installation

### Automatic

Once you have installed the Rocket Pool smart node client, simply run the `rocketpool service install` command to install the smart node service locally.

To install to a remote server, use `rocketpool --host example.com --user username --key /path/to/identity.pem service install`.

If your platform does not support automatic dependency installation, use the `-d` option to skip this step (e.g. `rocketpool service install -d`).
Then, manually install [docker](https://docs.docker.com/engine/install/) and [docker-compose](https://docs.docker.com/compose/install/).

### Manual

If you would prefer to check the installation script before running it, you may download and run it manually.

With cURL:
```
curl -L https://github.com/rocket-pool/smartnode-install/releases/latest/download/install.sh ./install.sh
chmod u+x ./install.sh
...
./install.sh
rm install.sh
```

With wget:
```
wget https://github.com/rocket-pool/smartnode-install/releases/latest/download/install.sh -O ./install.sh
chmod u+x ./install.sh
...
./install.sh
rm install.sh
```

### Available Options

The following options apply to both automatic and manual installation unless specified otherwise:

* `-r`: Verbose mode (print all output from the installation process) - automatic installation only
* `-d`: Skip automatic installation of OS dependencies
* `-n`: Specify a network to run the smart node stack on (default: medalla)
* `-v`: Specify a version of the smart node service package files to use (default: latest)

