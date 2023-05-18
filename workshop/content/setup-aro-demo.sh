#!/bin/bash

# Assuming AZ CLI, OC CLI, Helm, are already installed. Also that OC is already logged in with the kube:admin

#########################################################
# These are one time run upon provisioning the environment
#########################################################

# #These are already assumed to be envvars upon the environment provisioning
# AZURE_SUBSCRIPTION_ID=%azure_subscription_id%
# AZURE_TENANT_ID=%azure_tenant%
# SERVICE_PRINCIPAL_CLIENT_ID=%azappid%
# SERVICE_PRINCIPAL_CLIENT_SECRET=%azpass%
# REGION=eastus
# RESOURCE_GROUP=openenv-${GUID}
# PROJECT_NAME=ostoy-${GUID}
# KEYVAULT_NAME=secret-store-${GUID}


# List of environment variables to check
variables=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "SERVICE_PRINCIPAL_CLIENT_ID" "SERVICE_PRINCIPAL_CLIENT_SECRET" "REGION" "RESOURCE_GROUP" "PROJECT_NAME" "KEYVAULT_NAME")

# check if a variable is not set
is_variable_unset() {
    [[ -z "${!1}" ]]
}

# Iterate over the variables and check if they are not set
for variable in "${variables[@]}"; do
    if is_variable_unset "$variable"; then
        echo "$variable is not set."
    fi
done

#Create password for portal when required to change pw and store to file
openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 12 > azure_portal.pwd

# Configure cluster with ARC
curl -s https://raw.githubusercontent.com/microsoft/aroworkshop/master/resources/configure-arc.sh | bash & disown

#get required manifests
wget -q -P ${HOME} https://raw.githubusercontent.com/0kashi/aroworkshop/master/yaml/ostoy-microservice-deployment.yaml
curl -s https://raw.githubusercontent.com/0kashi/aroworkshop/master/yaml/ostoy-frontend-deployment.yaml | sed 's/#//g' > ${HOME}/ostoy-frontend-deployment.yaml

# Create the storage account
az storage account create --name ostoystorage${GUID} \
    --resource-group $RESOURCE_GROUP \
    --location $REGION \
    --sku Standard_ZRS \
    --encryption-services blob

#Store the connection string
az storage account show-connection-string --name ostoystorage${GUID} --resource-group ${RESOURCE_GROUP} -o tsv | tee ${HOME}/connection_string

az storage container create --name $PROJECT_NAME-container --account-name ostoystorage${GUID} --connection-string $CONNECTION_STRING
sleep 5
az keyvault create -n $KEYVAULT_NAME --resource-group ${RESOURCE_GROUP} --location $REGION
sleep 5
az keyvault secret set --vault-name $KEYVAULT_NAME --name connectionsecret --value $CONNECTION_STRING
sleep 5
az keyvault set-policy -n $KEYVAULT_NAME --secret-permissions get --spn $SERVICE_PRINCIPAL_CLIENT_ID
sleep 5

# Create SCC and SA
oc new-project ${PROJECT_NAME}
oc apply -f https://raw.githubusercontent.com/microsoft/aroworkshop/master/yaml/ostoyscc.yaml
oc create sa ostoy-sa -n $PROJECT_NAME
oc adm policy add-scc-to-user ostoyscc system:serviceaccount:${PROJECT_NAME}:ostoy-sa -n ${PROJECT_NAME}

echo "Please run the following to set proper environment variables."
# echo "export SERVICE_PRINCIPAL_CLIENT_SECRET=$SERVICE_PRINCIPAL_CLIENT_SECRET"
# echo "export SERVICE_PRINCIPAL_CLIENT_ID=$SERVICE_PRINCIPAL_CLIENT_ID"
# echo "export RESOURCE_GROUP=$RESOURCE_GROUP"
# echo "export AZURE_TENANT_ID=$AZURE_TENANT_ID"
# echo "export PROJECT_NAME=ostoy-${GUID}"
# echo "export KEYVAULT_NAME=secret-store-${GUID}"
# echo "export GUID=$GUID"
echo "export CONNECTION_STRING=$CONNECTION_STRING"