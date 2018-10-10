#!/bin/bash

# user defined parameters
LOCATION=""
RESOURCE_GROUP=""
AZURE_CLIENT_ID=""
AZURE_SECRET=""
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT=""
VNET=""
VNET_GROUP=""
SUBNET_APP=""
SUBNET_APPGW=""
APPDOCKER=""

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --location)
      LOCATION="$1"
      shift
      ;;
    --resource-group)
      RESOURCE_GROUP="$1"
      shift
      ;;
    --azure-client-id)
      AZURE_CLIENT_ID="$1"
      shift
      ;;
    --azure-secret)
      AZURE_SECRET="$1"
      shift
      ;;
    --azure-subscription-id)
      AZURE_SUBSCRIPTION_ID="$1"
      shift
      ;;
    --vnet)
      VNET="$1"
      shift
      ;;
    --appdocker)
      APPDOCKER="$1"
      shift
      ;;
    --subnet-app)
      SUBNET_APP="$1"
      shift
      ;;
    --subnet-appgw)
      SUBNET_APPGW="$1"
      shift
      ;;
    --azure-tenant)
      AZURE_TENANT="$1"
      shift
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done


function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    exit -1
  fi
}

VNET_GROUP=$RESOURCE_GROUP

#check parametrs
throw_if_empty --location $LOCATION
throw_if_empty --resource-group $RESOURCE_GROUP
throw_if_empty --azure-client-id $AZURE_CLIENT_ID
throw_if_empty --azure-secret $AZURE_SECRET
throw_if_empty --azure-subscription-id $AZURE_SUBSCRIPTION_ID
throw_if_empty --azure-tenant-id $AZURE_TENANT
throw_if_empty --vnet $VNET
throw_if_empty --appdocker $APPDOCKER
throw_if_empty --subnet-app $SUBNET_APP
throw_if_empty --subnet-appgw $SUBNET_APPGW

## Install pre-requisite packages
sudo yum check-update; sudo yum install -y git gcc libffi-devel python-devel openssl-devel epel-release
sudo yum install -y python-pip python-wheel

## Install Ansible and Azure SDKs via pip
sudo pip install ansible[azure]
ansible-galaxy install geerlingguy.docker
ansible-galaxy install geerlingguy.pip

#######################################
## START INSTALL

## switch to /opt
cd /opt

## clone git repo
git clone https://github.com/valda-z/vm-ansible-autodeploy.git /opt/appsetup

## generate ssh keypairs
ssh-keygen -f id_rsa -t rsa -N ''
mkdir -p /root/.ssh
mv id_rsa /root/.ssh/
mv id_rsa.pub /root/.ssh/

cd appsetup/ansible

## suppress ssh warning
echo "[defaults]
host_key_checking = False" > ansible.cfg

## create annsible config for azure access
mkdir -p /root/.azure
echo "[default]" > /root/.azure/credentials
echo "subscription_id=${AZURE_SUBSCRIPTION_ID}" >> /root/.azure/credentials
echo "client_id=${AZURE_CLIENT_ID}" >> /root/.azure/credentials
echo "secret=${AZURE_SECRET}" >> /root/.azure/credentials
echo "tenant=${AZURE_TENANT}" >> /root/.azure/credentials

SSH_KEY=$(cat /root/.ssh/id_rsa.pub)
## create ansible variables
echo "group: \"${RESOURCE_GROUP}\"" > config.yaml
echo "location: \"${LOCATION}\"" >> config.yaml
echo "vnet: \"${VNET}\"" >> config.yaml
echo "vnetgroup: \"${VNET_GROUP}\"" >> config.yaml
echo "subnet: \"${SUBNET_APP}\"" >> config.yaml
echo "subnetappgw: \"${SUBNET_APPGW}\"" >> config.yaml
echo "adminusr: \"appusr\"" >> config.yaml
echo "adminsshkey: \"${SSH_KEY}\"" >> config.yaml

## myapp serviced definition
echo "[Unit]
Description=MyApp
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull ${APPDOCKER}
ExecStart=/usr/bin/docker run --rm -p 8080:80 --name %n ${APPDOCKER}

[Install]
WantedBy=multi-user.target" > docker.myapp.service

## create and deploy infra and SW
ansible-playbook deployment.yaml

