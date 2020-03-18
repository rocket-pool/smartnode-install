# Install OS dependencies
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -y update
sudo apt-get -y install docker-ce

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod a+rx /usr/local/bin/docker-compose

# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER
