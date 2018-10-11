#!/bin/bash

# user defined parameters
APPDOCKER=""

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --appdocker)
      APPDOCKER="$1"
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


#check parametrs
throw_if_empty --appdocker $APPDOCKER

#######################################
## START INSTALL

## switch to /opt
cd /opt

cd appsetup/ansible
## pull git repo
git pull 

## suppress ssh warning
echo "[defaults]
host_key_checking = False" > ansible.cfg

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

