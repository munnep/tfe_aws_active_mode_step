#!/bin/bash

# wait until archive is available. Wait until there is internet before continue
until ping -c1 archive.ubuntu.com &>/dev/null; do
 echo "waiting for networking to initialise"
 sleep 3 
done 

# install monitoring tools
apt-get update
apt-get install -y ctop net-tools sysstat 

# Install jq needed for scripting during installation
apt-get install -y jq

# Set swappiness
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

# swapping settings
sysctl vm.swappiness=1
sysctl vm.min_free_kbytes=67584
sysctl vm.drop_caches=1
# make it permanent over server reboots
echo vm.swappiness=80 >> /etc/sysctl.conf
echo vm.min_free_kbytes=67584 >> /etc/sysctl.conf


SWAP=/dev/$(lsblk|grep nvme | grep -v nvme0n1 |sort -k 4 | awk '{print $1}'| awk '(NR==1)')
DOCKER=/dev/$(lsblk|grep nvme | grep -v nvme0n1 |sort -k 4 | awk '{print $1}'| awk '(NR==2)')


echo $SWAP
echo $DOCKER
echo $TFE

# swap
# if SWAP exists
# we format if no format
if [ -b $SWAP ]; then
	blkid $SWAP
	if [ $? -ne 0 ]; then
		mkswap $SWAP
	fi
fi

# if SWAP not in fstab
# we add it
grep "$SWAP" /etc/fstab
if [ $? -ne 0 ]; then
	echo "$SWAP swap swap defaults 0 0" | tee -a /etc/fstab
	swapon -a
fi

# docker
# if DOCKER exists
# we format if no format
if [ -b $DOCKER ]; then
	blkid $DOCKER
	if [ $? -ne 0 ]; then
		mkfs.xfs $DOCKER
	fi
fi

# if DOCKER not in fstab
# we add it
grep "$DOCKER" /etc/fstab
if [ $? -ne 0 ]; then
	echo "$DOCKER /var/lib/docker xfs defaults 0 0" | tee -a /etc/fstab
	mkdir -p /var/lib/docker
	mount -a
fi



# Netdata will be listening on port 19999
curl -sL https://raw.githubusercontent.com/automodule/bash/main/install_netdata.sh | bash

# install requirements for tfe
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get -y install docker-ce=5:20.10.17~3-0~ubuntu-$(lsb_release -sc) docker-ce-cli=5:20.10.17~3-0~ubuntu-$(lsb_release -sc) containerd.io docker-compose-plugin

# Download all the software and files needed
apt-get -y install awscli
aws s3 cp s3://${tag_prefix}-software/${filename_airgap} /tmp/${filename_airgap}
aws s3 cp s3://${tag_prefix}-software/${filename_license} /tmp/${filename_license}
aws s3 cp s3://${tag_prefix}-software/${filename_bootstrap} /tmp/${filename_bootstrap}

# directory for decompress the file
sudo mkdir -p /opt/tfe
pushd /opt/tfe
sudo tar xzf /tmp/replicated.tar.gz

cat > /tmp/tfe_settings.json <<EOF
{
   "aws_instance_profile": {
        "value": "1"
    },
    "enc_password": {
        "value": "${tfe_password}"
    },
    "hairpin_addressing": {
        "value": "1"
    },
    "hostname": {
        "value": "${dns_hostname}.${dns_zonename}"
    },
    "pg_dbname": {
        "value": "${pg_dbname}"
    },
    "pg_netloc": {
        "value": "${pg_address}"
    },
    "pg_password": {
        "value": "${rds_password}"
    },
    "pg_user": {
        "value": "postgres"
    },
    "placement": {
        "value": "placement_s3"
    },
    "production_type": {
        "value": "external"
    },
    "s3_bucket": {
        "value": "${tfe_bucket}"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "${region}"
    }
}
EOF


# replicated.conf file
cat > /etc/replicated.conf <<EOF
{
    "DaemonAuthenticationType":          "password",
    "DaemonAuthenticationPassword":      "${tfe_password}",
    "TlsBootstrapType":                  "self-signed",
    "TlsBootstrapHostname":              "${dns_hostname}.${dns_zonename}",
    "BypassPreflightChecks":             true,
    "ImportSettingsFrom":                "/tmp/tfe_settings.json",
    "LicenseFileLocation":               "/tmp/${filename_license}",
    "LicenseBootstrapAirgapPackagePath": "/tmp/${filename_airgap}"
}
EOF

# script that can be used to configure the environment easily for the first time
cat > /tmp/tfe_setup.sh <<EOF
#!/usr/bin/env bash

# only really needed when not using valid certificates
# echo -n | openssl s_client -connect ${dns_hostname}.${dns_zonename}:443 | openssl x509 > tfe_certificate.crt
# sudo cp tfe_certificate.crt /usr/local/share/ca-certificates/
# sudo update-ca-certificates

# We have to wait for TFE be fully functioning before we can continue
while true; do
    if curl -I "https://${dns_hostname}.${dns_zonename}/admin" 2>&1 | grep -w "200\|301" ; 
    then
        echo "TFE is up and running"
        echo "Will continue in 1 minutes with the final steps"
        sleep 60
        break
    else
        echo "TFE is not available yet. Please wait..."
        sleep 60
    fi
done

# get the admin token you can use to create the first user
ADMIN_TOKEN=\`sudo /usr/local/bin/replicated admin --tty=0 retrieve-iact | tr -d '\r'\`

# Create the first user called admin and get the token
TOKEN=\`curl --header "Content-Type: application/json" --request POST --data '{"username": "admin", "email": "${certificate_email}", "password": "${tfe_password}"}' \ --url https://${dns_hostname}.${dns_zonename}/admin/initial-admin-user?token=\$ADMIN_TOKEN | jq '.token' | tr -d '"'\`

# create the organization called test
curl \
  --header "Authorization: Bearer \$TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{"data": { "type": "organizations", "attributes": {"name": "test", "email": "${certificate_email}"}}}' \
  https://${dns_hostname}.${dns_zonename}/api/v2/organizations

# Create a workspace named test-workspace
curl \
  --header "Authorization: Bearer \$TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{"data": {"attributes": {"name": "test-workspace", "resource-count": 0, "updated-at": "2017-11-29T19:18:09.976Z"}, "type": "workspaces"}}' \
  https://${dns_hostname}.${dns_zonename}/api/v2/organizations/test/workspaces
EOF

# Following manual:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4`
echo $LOCAL_IP

sudo bash ./install.sh airgap private-address=$LOCAL_IP
