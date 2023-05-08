# Manual steps

This document describes the manual steps for creating a TFE active/active cluster behind an application load balancer with an Autoscaling group which you can then connect to over the internet. The TFE is in a private subnet

See below diagram for how the setup is:
![](../diagram/diagram_tfe_active_mode.png)

# Create TFE airgap Autoscaling group with loadbalancer single instance
## network
- Create a VPC with cidr block ```10.238.0.0/16```  
![](media/20220912133108.png)  
- Create 4 subnets. 2 public subnets and 2 private subnet
    - patrick-public1-subnet (ip: ```10.238.1.0/24``` availability zone: ```eu-north-1a```)  
    - patrick-public2-subnet (ip: ```10.238.2.0/24``` availability zone: ```eu-north-1b```)  
    - patrick-private1-subnet (ip: ```10.238.11.0/24``` availability zone: ```eu-north-1a```)  
    - patrick-private2-subnet (ip: ```10.238.12.0/24``` availability zone: ```eu-north-1b```)  
![](media/20220912133359.png)    
![](media/20220912133414.png)    
- create an internet gateway and attach to VPC  
![](media/20220912133448.png)   
![](media/20220912133514.png)    
- create a nat gateway which you attach to ```patrick-public1-subnet```   
![](media/20220912133618.png)    
- create routing table for public  
![](media/20220912133707.png)    
   - edit the routing table for internet access to the internet gateway
   ![](media/20220912133804.png)    
- create routing table for private  
   ![](media/20220912133926.png)     
   - edit the routing table for internet access to the nat gateway  
   ![](media/20220912134020.png)     
- attach routing tables to subnets  
    - patrick-public-route to public subnets      
    ![](media/20220912134139.png)       
    - patrick-private-route to private subnet   
     ![](media/20220912134105.png)  
- create a security group that allows  
https    
8800     
port 5432 for PostgreSQL database    
6379 redis  
8201 vault  
![](media/20220912134534.png)  
- 

## Create the RDS postgresql instance
Creating the RDS postgreSQL instance to use with TFE instance

- PostgreSQL instance version 14  
![](media/20220912135024.png)   
![](media/20220912135037.png)    
![](media/20220912135050.png)    
![](media/20220912135110.png)    
![](media/20220912135124.png)    



endpoint: ```patrick-tfe-rds.cvwddldymexr.eu-north-1.rds.amazonaws.com```

# AWS to use
- create a bucket patrick-tfe-manual and patrick-tfe-software  
![](media/20220912135225.png)      
![](media/20220912135307.png)    
- upload the following files to patrick-tfe-software  
airgap file  
license file  
bootstrap file  


- create IAM policy to access the buckets from the created instance  
- create a new policy  
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::patrick-tfe-manual",
                "arn:aws:s3:::patrick-tfe-software",
                "arn:aws:s3:::*/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}
```

- create a new role    
![](media/20220520124616.png)     
![](media/20220520124635.png)    
![](media/20220520124711.png)    


## certificates  
import certificates for patrick-tfe2.bg.hashicorp-success.com
![](media/20220520124850.png)      
![](media/20220520124941.png)      
![](media/20220925133852.png)      

# Launch a stepping stone instance

![](media/20220912141116.png)      

# Auto Launch scaling group

- Create an auto launch scaling group  
![](media/20220925105450.png)    
![](media/20220925105711.png)  
![](media/20220925112226.png)       
![](media/20220925112259.png)    

```
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


# Netdata will be listening on port 19999
# curl -sL https://raw.githubusercontent.com/automodule/bash/main/install_netdata.sh | bash

# install requirements for tfe
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Download all the software and files needed
apt-get -y install awscli
aws s3 cp s3://patrick-tfe-software/652.airgap /tmp/652.airgap
aws s3 cp s3://patrick-tfe-software/license.rli /tmp/license.rli
aws s3 cp s3://patrick-tfe-software/replicated.tar.gz /tmp/replicated.tar.gz

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
        "value": "Password#1"
    },
    "hairpin_addressing": {
        "value": "1"
    },
    "hostname": {
        "value": "patrick-tfe2.bg.hashicorp-success.com"
    },
    "pg_dbname": {
        "value": "tfe"
    },
    "pg_netloc": {
        "value": "patrick-manual-rds.cvwddldymexr.eu-north-1.rds.amazonaws.com"
    },
    "pg_password": {
        "value": "Password#1"
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
        "value": "patrick-tfe-manual"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "eu-north-1"
    }
}
EOF


# replicated.conf file
cat > /etc/replicated.conf <<EOF
{
    "DaemonAuthenticationType":          "password",
    "DaemonAuthenticationPassword":      "Password#1",
    "TlsBootstrapType":                  "self-signed",
    "TlsBootstrapHostname":              "patrick-tfe2.bg.hashicorp-success.com",
    "BypassPreflightChecks":             true,
    "ImportSettingsFrom":                "/tmp/tfe_settings.json",
    "LicenseFileLocation":               "/tmp/license.rli",
    "LicenseBootstrapAirgapPackagePath": "/tmp/652.airgap"
}
EOF


# Following manual:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4`
echo $LOCAL_IP

sudo bash ./install.sh airgap private-address=$LOCAL_IP

```
![](media/20220925113034.png)    
![](media/20220925113055.png)    
![](media/20220925113114.png)    
![](media/20220925113134.png)    

- The launch configuration should now be visible  
![](media/20220925113209.png)  

# Loadbalancer


- loadbalancer create a target group which we at a later point connect to the Auto Scaling Group  
 ![](media/20220520133657.png)  
 ![](media/20220520133733.png)    
- Will have no targets yet  
![](media/20220520133755.png)    

- do the same for the tfe-app port 443

- loadbalancer create a appplication load balancer which will connect to the load balancer target    
![](media/20220520133950.png)    
- following configuration  
![](media/20220520134014.png)  
![](media/20220520134040.png)    
![](media/20220520134059.png)    
![](media/20220520134138.png)    
![](media/20220520134318.png)    
![](media/20220520134341.png)    


- Auto Scaling groups. Will configure the group and connect it to auto scaling launch and the created load balancer
Make sure you switch to launch configuration   
![](media/20220925113821.png)    
![](media/20220925113853.png)    
![](media/20220925135406.png)    
![](media/20220925114017.png)   
![](media/20220925114039.png)     

- You should now see an instance being started   
![](media/20220925135505.png)      

- Alter the DNS record in route53 to point to the loadbalancer dns name    
![](media/20220520134508.png)  

- You should now be able to connect to your website   


# Active/Active

## Create a Redis environment

Get a elasticache Redis environment  
![](media/20220912155231.png)    
![](media/20220912155647.png)    
![](media/20220912155656.png)    
![](media/20220925140444.png)    
![](media/20220912155716.png)    
![](media/20220912155726.png)    
![](media/20220912155737.png)    
![](media/20220912155803.png)    
![](media/20220912155819.png)    


## test connection to Redis
```
https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/GettingStarted.ConnectToCacheNode.html

patrick-example.1yhbvq.0001.eun1.cache.amazonaws.com:6379
sudo apt install redis-server

redis-cli -h patrick-tfe.1yhbvq.ng.0001.eun1.cache.amazonaws.com -c -p 6379
```



## Create a second Launch configuration for active active

- Create an auto launch scaling group  
![](media/20220925115054.png)  
![](media/20220925112226.png)       
![](media/20220925112259.png)    

```
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


# Netdata will be listening on port 19999
# curl -sL https://raw.githubusercontent.com/automodule/bash/main/install_netdata.sh | bash

# install requirements for tfe
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Download all the software and files needed
apt-get -y install awscli
aws s3 cp s3://patrick-tfe-software/652.airgap /tmp/652.airgap
aws s3 cp s3://patrick-tfe-software/license.rli /tmp/license.rli
aws s3 cp s3://patrick-tfe-software/replicated.tar.gz /tmp/replicated.tar.gz

# directory for decompress the file
sudo mkdir -p /opt/tfe
pushd /opt/tfe
sudo tar xzf /tmp/replicated.tar.gz

cat > /tmp/tfe_settings.json <<EOF
{
   "enable_active_active" : {
        "value": "1"
   },
   "aws_instance_profile": {
        "value": "1"
    },
    "enc_password": {
        "value": "Password#1"
    },
    "hairpin_addressing": {
        "value": "1"
    },
    "hostname": {
        "value": "patrick-tfe2.bg.hashicorp-success.com"
    },
    "pg_dbname": {
        "value": "tfe"
    },
    "pg_netloc": {
        "value": "patrick-manual-rds.cvwddldymexr.eu-north-1.rds.amazonaws.com"
    },
    "pg_password": {
        "value": "Password#1"
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
     "redis_host" : {
      "value": "patrick-tfe.1yhbvq.ng.0001.eun1.cache.amazonaws.com"
    },
    "redis_port" : {
      "value": "6379"
    },
    "redis_use_password_auth" : {
      "value": "0"
    },
    "redis_use_tls" : {
      "value": "0"
    },
    "s3_bucket": {
        "value": "patrick-tfe-manual"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "eu-north-1"
    }
}
EOF


# replicated.conf file
cat > /etc/replicated.conf <<EOF
{
    "DaemonAuthenticationType":          "password",
    "DaemonAuthenticationPassword":      "Password#1",
    "TlsBootstrapType":                  "self-signed",
    "TlsBootstrapHostname":              "patrick-tfe2.bg.hashicorp-success.com",
    "BypassPreflightChecks":             true,
    "ImportSettingsFrom":                "/tmp/tfe_settings.json",
    "LicenseFileLocation":               "/tmp/license.rli",
    "LicenseBootstrapAirgapPackagePath": "/tmp/652.airgap"
}
EOF


# Following manual:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4`
echo $LOCAL_IP

sudo bash ./install.sh airgap private-address=$LOCAL_IP disable-replicated-ui

```
![](media/20220925113034.png)    
![](media/20220925113055.png)    
![](media/20220925113114.png)    
![](media/20220925113134.png)    

- The launch configuration should now be visible  
![](media/20220925115135.png)    

## switch to active active
- Go to the Auto Scaling groups 
- Edit the group
- change the launch configuration   
![](media/20220925143425.png)    
- click update
- Terminate the instance you currently use
- Wait for TFE to become online

### Add a second node
- Go to the Auto Scaling groups and edit the group to use minimum of 2 instances
![](media/20220925115957.png)    

### Check TFE is working properly by creating a TFE run

- go the directory `test_terraform`
```
cd test_terraform
```
- change the `main.tf` with your own values in the connect string
```
terraform {
  cloud {
    hostname = "patrick-tfe2.bg.hashicorp-success.com"             <-- change this line with your own
    organization = "test"

    workspaces {
      name = "test-workspace"                                       <-- change this line with your own
    }
  }
}
```
- login with terraform

```
terraform login patrick-tfe2.bg.hashicorp-success.com
```
- Run terraform init
```
terraform init
```
- run terraform apply
```
terraform apply
```
- See the result in TFE itself
- If this succeeds you have a working active-active tfe environment  
![](media/20220921193401.png)    
