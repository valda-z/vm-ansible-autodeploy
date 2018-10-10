# Deploy application environment by ansible

Aim of this experiment is to deliver automated installation for complex environment which contains
* VNET divided to 3 subnets (gateway, application and jumpbox)
* deploy simple jumpbox which will be initialized by automation scripts and than it is used to provision rest of solution
* ansible playbook which runs on jumpbox and deploy infrastructure and software
* script for redeploying software

Applications which runs on application server are dockerized and docker images are run by systemd.

Idea behind for updating application - push new version of application image to registry and use new tag (build or version number) - this new value is than passed to redeploy script which changes systemd definition for our service and restarts service with new version.

## Prerequisites

In experiment we will create new Service Principal for authentication, new resource group and new VNET with subnets, you can skip these steps if you have already initialized environment.
Installation will be started from cloud shell ( https://shell.azure.com ).

### Create resource group

```bash
export RESOURCE_GROUP="QTEST"
export LOCATION="northeurope"

# create RG
az group create -l ${LOCATION} -n ${RESOURCE_GROUP}
```

### Create Service Principal

```bash
export AZURE_SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
export AZURE_TENANT=$(az account show --query "tenantId" --output tsv)

# create Service Principal
AZURE_SP_TMP=$(az ad sp create-for-rbac -n "myAppTestDeploy${RESOURCE_GROUP}" --role contributor \
--scopes /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} )
export AZURE_CLIENT_ID=$(echo $AZURE_SP_TMP | jq ".appId" -r)
export AZURE_SECRET=$(echo $AZURE_SP_TMP | jq ".password" -r)
```

### Create VNET and subnets

```bash
export VNET=vnet
export SUBNETJUMPBOX=jumpbox
export SUBNETAPP=app
export SUBNETGW=gateway

# Create VNET
az network vnet create -g ${RESOURCE_GROUP} -n ${VNET} --address-prefix 10.0.0.0/16 \
                            --subnet-name ${SUBNETJUMPBOX} --subnet-prefix 10.0.100.0/24

# Create subnets
az network vnet subnet create -g ${RESOURCE_GROUP} --vnet-name ${VNET} -n ${SUBNETGW} \
                            --address-prefix 10.0.0.0/24
az network vnet subnet create -g ${RESOURCE_GROUP} --vnet-name ${VNET} -n ${SUBNETAPP} \
                            --address-prefix 10.0.1.0/24
```

### Create jumpbox (and install whole app solution)

```bash
# my public ssh-key
export MYSSHKEY="xxxxxxxxxxxx"

# my docker image for app
export MYDOCKERAPP="dockercloud/hello-world:latest"

# create cloud-init.txt
echo "
#cloud-config
package_upgrade: false
packages:
  - curl
runcmd:
  - curl -s https://raw.githubusercontent.com/valda-z/vm-ansible-autodeploy/master/deploy.sh | bash -s -- --location ${LOCATION} --resource-group ${RESOURCE_GROUP} --azure-client-id ${AZURE_CLIENT_ID} --azure-secret ${AZURE_SECRET} --azure-subscription-id ${AZURE_SUBSCRIPTION_ID} --azure-tenant ${AZURE_TENANT} --vnet ${VNET}  --subnet-app ${SUBNETAPP} --subnet-appgw ${SUBNETGW} --appdocker ${MYDOCKERAPP}
" > cloud-init.txt 

# create VM
az vm create --name jumpbox \
  --resource-group ${RESOURCE_GROUP} \
  --admin-username myadmin \
  --authentication-type ssh \
  --location ${LOCATION} \
  --no-wait \
  --nsg-rule SSH \
  --image "OpenLogic:CentOS:7-CI:latest" \
  --vnet-name ${VNET} \
  --subnet ${SUBNETJUMPBOX} \
  --size Standard_D1_v2 \
  --ssh-key-value "${MYSSHKEY}" \
  --custom-data cloud-init.txt
```

After few minutes you can see deployed jumpbox and rest of infrastructure (application gateway and one application server)

### Test it

Now you can access jumpbox vi ssh (see connection information on VM Overview page).

In jumpbox we have installed in /opt/appsetup folder deployment and redeploy scripts.

If you want to run redeploy (beacuse of new version of docker image you can run this script):

```bash
cd /opt/appsetup
./redeploy.sh --appdocker dockercloud/hello-world:latest
```
