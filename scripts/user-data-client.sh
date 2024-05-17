#!/usr/bin/env bash

# wait until archive is available. Wait until there is internet before continue
until ping -c1 archive.ubuntu.com &>/dev/null; do
 echo "waiting for networking to initialise"
 sleep 3 
done 

export DEBIAN_FRONTEND=noninteractive

# install terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

apt-get update -y
apt-get install -y terraform=${terraform_client_version}
