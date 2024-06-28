#!/bin/bash
set -v

# Assuming Nutanix Prism is already installed and accessible at this point
# Replace these variables with actual values

sudo apt-get update && sudo apt-get install -y curl jq

#PRISM_IP="192.168.103.252"
#PRISM_USER="admin"
#PRISM_PASSWORD="Nutanix/4u)"
#AD_DOMAIN="147.75.205.246"
#AD_USERNAME="admin"
#AD_PASSWORD="Equinix@AD"
#BASTION_PUBLIC_KEY="147.28.207.213"

# Login to Prism and get a session token
# The specifics of these commands will depend on the Nutanix API and may need adjustment
TOKEN=$(curl -s -k -X POST https://$PRISM_IP:9440/PrismGateway/services/rest/v1/utils/login \
    -H 'Content-Type: application/json' \
    --data-binary '{"username":"'"$PRISM_USER"'","password":"'"$PRISM_PASSWORD"'"}' \
    | jq -r '.session_token')

echo "$TOKEN"

# Configure AD authentication (adjust payload as needed for your AD setup)
curl -s -k -X POST https://$PRISM_IP:9440/PrismGateway/services/rest/v1/authconfig/directories \
    -H "Authorization: Bearer $TOKEN" \
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