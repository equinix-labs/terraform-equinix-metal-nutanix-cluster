#!/bin/bash

# Install prerequisites, e.g., curl or jq for JSON parsing if needed
# sudo apt-get update && sudo apt-get install -y curl jq

# Assuming Nutanix Prism is already installed and accessible at this point
# Replace these variables with actual values
PRISM_IP=""
PRISM_USER="admin"
PRISM_PASSWORD=""
AD_DOMAIN=""
AD_USERNAME=""
AD_PASSWORD=""

ssh -L 9440:$CVM_IP_ADDRESS:9440 -L 19440:$PRISM_IP:9440 -i $PRIVATE_KEY root@$BASTION_PUBLIC_KEY

# Login to Prism and get a session token
# The specifics of these commands will depend on the Nutanix API and may need adjustment
TOKEN=$(curl -s -k -X POST https://$PRISM_IP:9440/PrismGateway/services/rest/v1/utils/login \
    -H 'Content-Type: application/json' \
    --data-binary '{"username":"'"$PRISM_USER"'","password":"'"$PRISM_PASSWORD"'"}' \
    | jq -r '.session_token')

# Configure AD authentication (adjust payload as needed for your AD setup)
curl -s -k -X POST https://$PRISM_IP:9440/PrismGateway/services/rest/v1/authconfig/directories \
    -H "Authorization: Bearer $TOKEN"
    -H 'Content-Type: application/json' --data-binary '{
                                                         "name": "'"$AD_DOMAIN"'",
                                                          "directoryUrl": "ldap://'$AD_DOMAIN'",
                                                          "domain": "'"$AD_DOMAIN"'",
                                                          "serviceAccountUsername": "'"$AD_USERNAME"'",
                                                          "serviceAccountPassword": "'"$AD_PASSWORD"'",
                                                          "connectionType": "LDAP",
                                                          "directoryType": "ACTIVE_DIRECTORY"
                                                        }'

if [ "$?" -eq 0 ]; then
    echo "AD authentication configured successfully."
else
    echo "Failed to configure AD authentication."
fi