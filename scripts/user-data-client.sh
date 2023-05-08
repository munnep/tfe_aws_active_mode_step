#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive


# install terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

apt-get update -y
apt-get install -y terraform=${terraform_client_version}

# add a public key for authorization
# first is Alvaro
cat >> /home/ubuntu/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBzMaSE9ORQsJoIi+UrMQ+U8WFSpiYFXIKSvqFWbqyhpEM6MSoidX09CuvYIVPMtTeZZj/ZO+o+nL0TffIDNzkGgalhdlw5RL9OgJXgmUNWjW4VwIoR96D7TcP6EUyXkD0wxSgjryJSn4aONR3tIIYvHdM9YjRrivLlS/N7WzIRM6xvWJ8UK7fVYdD3V6FMp4+a33Uc+Ezk8XPWCvDt5vXluFPiKa8RlU7XXqPqI2bR89VJ5cpCnZorVtjVVlvgtOFdY/5hT7qqX1hxQyARkSLcnJiVylL3H3arDlnT/6nO71WY2/ZfyVUbQqcTC12UpFSJRH7JRCgf0stTdfzugCsq61XCMkZBfZ2OTBWeO8Qm2yDW7d4NwzKj31xKqDxT3sr7Gz6qiJO0XhaEjgBSAFB41hVDaNR8Fa6Ir1DObVQ+QsHOv4m2xhh8XxLaZZh30KWZNFAxVmeXoec0paDuj53UTM/ddhbKQr+8vPkbdlR4p5hxSSoVH+SBNLmGY4+K+0= kikitux@kikitux-C02ZR1GLLVDM
EOF