# Get the Docker signing key for packages
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo apt-key add -

# Add the Docker official repos
echo "deb [arch=armhf] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
     $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list

# Install Docker
# The aufs package, part of the "recommended" packages, won't install on Buster just yet, because of missing pre-compiled kernel modules.
# We can work around that issue by using "--no-install-recommends"
sudo apt update
sudo apt install -y --no-install-recommends \
    docker-ce \
    cgroupfs-mount

# Install docker-compose
sudo apt update
sudo apt install -y python python-pip libffi-dev python-backports.ssl-match-hostname

echo "*** Installing Docker Compose via PiP for Raspberry Pi, this can take a while, go get a drink... ***********"

# Install Docker Compose from pip
# This might take a while
sudo pip install docker-compose

# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER