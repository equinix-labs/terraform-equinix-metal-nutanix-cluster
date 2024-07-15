#!/bin/bash
set -v

# Assuming Nutanix Prism is already installed and accessible at this point
# Replace these variables with actual values

sudo apt-get update && sudo apt-get install -y curl jq

# Variables
PRISM_IP="192.168.103.252"
PRISM_PORT="9440"
USERNAME="admin"
PASSWORD="A@yush17"
VIRTUAL_IP="192.168.103.254"
ISCSI_IP="192.168.103.253"
NTP_SERVER="0.north-america.pool.ntp.org"
PRISM_CENTRAL_IP="192.168.103.252"
SUBNET_MASK="255.255.252.0"
GATEWAY="192.168.100.2"
VM_IP="192.168.103.252"
DNS_SERVERS=("1.1.1.1" "8.8.8.8")
PRISM_CENTRAL_IP="your_prism_central_ip"
DEFAULT_PASSWORD="Nutanix/4u"
NEW_PASSWORD="A@yush17"

TOKEN=$(printf '%s:%s' "$USERNAME" "$PASSWORD" | base64)

# Function to make API requests
api_request() {
    local METHOD=$1
    local ENDPOINT=$2
    local DATA=$3
    curl -s -k -X $METHOD "https://$PRISM_IP:$PRISM_PORT/$ENDPOINT" \
        --header 'Accept: application/json' \
        --header "Authorization: Basic $TOKEN" \
        --header 'Content-Type: application/json' \
        --data "$DATA"

    if [ "$?" -ne 0 ]; then
        echo "https://$PRISM_IP:$PRISM_PORT/$ENDPOINT failed"
        exit 1
    fi
}

# Get cluster list
clusters=$(api_request "POST" "api/nutanix/v3/clusters/list" '{
                                                                "kind": "cluster",
                                                                "length": 1,
                                                                "offset": 0
                                                              }')
cluster_uuid=$(echo "$clusters" | jq -r '.entities[] | select(.spec.name == "equinix-nutanix-demo") | .metadata.uuid')

# 1. Set Virtual IP and iSCSI Data Services IP, NTP server
cluster_metadata=$(echo "$clusters" | jq -r '.entities[] | select(.spec.name == "equinix-nutanix-demo") | .metadata')
cluster_spec=$(echo "$clusters" | jq -r '.entities[] | select(.spec.name == "equinix-nutanix-demo") | .spec')
updated_spec=$(echo "$cluster_spec" | jq '
  .resources.network.external_ip = "'"$VIRTUAL_IP"'" |
  .resources.network.external_data_services_ip = "'"$ISCSI_IP"'" |
  .resources.network.ntp_server_ip_list = ["'"$NTP_SERVER"'"]
')

api_request "PUT" "api/nutanix/v3/clusters/$cluster_uuid" '{
    "spec": '"$updated_spec"',
    "metadata": '"$cluster_metadata"'
}'

# 2. create a subnet
vm_network=$(api_request "POST" "api/nutanix/v3/subnets" '{
  "api_version": "3.1",
  "metadata": {
    "kind": "subnet"
  },
  "spec": {
    "name": "VM Network 1",
    "resources": {
      "subnet_type": "VLAN",
      "vlan_id": 0,
      "ip_config": {
        "prefix_length": 22,
        "gateway_ip": "192.168.100.2",
        "pool_list": [
          {
            "start_ip": "192.168.100.2",
            "end_ip": "192.168.103.254"
          }
        ]
      }
    }
  }
}')

network_uuid=$(echo "$vm_network" | jq -r '.metadata.uuid')

# 3. Deploy Prism Central
api_request "GET" "api/nutanix/v3/prism_central" '{
"spec": {
  "name": "PC Instance 1",
  "resources": {
    "power_state": "ON",
    "num_vcpus_per_socket": 1,
    "num_sockets": 1,
    "memory_size_mib": 8192,
    "disk_list": [
      {
        "disk_size_mib": 81920,
        "device_properties": {
          "device_type": "DISK"
        }
      }
    ],
    "nic_list": [
      {
        "nic_type": "NORMAL_NIC",
        "is_connected": true,
        "ip_endpoint_list": [
          {
            "ip_type": "DHCP"
          }
        ],
        "subnet_reference": {
          "kind": "subnet",
          "name": "VM Network",
          "uuid": "'"$network_uuid"'"
        }
      }
    ],
    "guest_tools": {
      "nutanix_guest_tools": {
        "state": "ENABLED",
        "iso_mount_state": "MOUNTED"
      }
    }
  },
  "cluster_reference": {
    "kind": "cluster",
    "name": "equinix-nutanix-demo",
    "uuid": "'"$cluster_uuid"'"
  }
},
"api_version": "3.1.0",
"metadata": {
  "kind": "vm"
}
}'

api_request "POST" "api/nutanix/v3/prism_central" '{
"spec": {
"name": "PrismCentralName",
"resources": {
  "version": "pc_version",
  "pc_vm_list": [
    {
      "cpu": 8,
      "memory": 32,
      "disk_size_gb": 500,
      "network_configuration": {
        "network_uuid": "'"$network_uuid"'",
        "subnet_mask": "255.255.252.0",
        "gateway": "192.168.100.2",
        "ip_list": ["192.168.103.252"]
      }
    }
  ]
      }
    },
    "api_version": "3.1",
    "metadata": {
      "kind": "prism_central"
    }
  }'

   # Wait for Prism Central to deploy
   echo "Waiting for Prism Central deployment to complete..."
#   sleep 100  # Adjust sleep duration based on your environment

   # 4. Log in to Prism Central and change password
   # This step cannot be fully automated in a shell script due to interactive login. You can use tools like expect or automate this in a more advanced automation framework.

    # Function to change the password
    change_password() {
      auth_token=$1
      response=$(curl -s -X PUT "https://$PRISM_IP:9440/api/nutanix/v3/users/me/change_password" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $auth_token" \
        -d '{
              "current_password": "'$DEFAULT_PASSWORD'",
              "new_password": "'$NEW_PASSWORD'"
            }' -k)
      echo $response
    }

    # Get authentication token
    AUTH_TOKEN=$(get_auth_token)

    # Check if we got the token successfully
    if [ -z "$AUTH_TOKEN" ]; then
      echo "Failed to get authentication token. Please check your credentials and IP address."
      exit 1
    fi

    # Change the password
    change_password $AUTH_TOKEN
    echo "Password change request sent. Please verify the new password."

   # 5. Register Prism Central VM
   api_request "POST" "api/nutanix/v3/prism_central_register" '{
     "prism_central_ip": "'"$PRISM_IP"'",
     "port": "'"$PRISM_PORT"'"
   }'

   # 6. Configure DNS Servers in Prism Central
   api_request "PUT" "api/nutanix/v3/prism_central/dns_servers" '{
     "dns_servers": ["'"${DNS_SERVERS[0]}"'", "'"${DNS_SERVERS[1]}"'"]
   }'

   # 7. Configure NTP Server in Prism Central
   api_request "PUT" "api/nutanix/v3/prism_central/ntp_servers" '{
     "ntp_servers": ["'"$NTP_SERVER"'"]
   }'

   echo "Prism Central configuration completed successfully."

#######################
# Step 1: Set up Virtual IP, iSCSI IP, and NTP for the Cluster
curl -u "$username:$password" -k -X POST "https://$prismCentralIP:9440/api/nutanix/v3/clusters/configure" -H "Content-Type: application/json" -d '{
  "virtualIP": "'$clusterVirtualIP'",
  "iSCSIIP": "'$clusterISCSIIP'",
  "ntpServers": ["0.north-america.pool.ntp.org"]
}'

# Step 3: Deploy Prism Central
curl -X POST "https://<Prism_Element_IP>:9440/api/nutanix/v3/prism_central" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer <session_token>" \
-d '{
  "spec": {
    "name": "PrismCentralName",
    "resources": {
      "version": "pc_version",
      "pc_vm_list": [
        {
          "cpu": 8,
          "memory": 32,
          "disk_size_gb": 500,
          "network_configuration": {
            "network_uuid": "'"$network_uuid"'",
            "subnet_mask": "255.255.252.0",
            "gateway": "192.168.100.2",
            "ip_list": ["192.168.103.252"]
          }
        }
      ]
          }
        },
        "api_version": "3.1",
        "metadata": {
          "kind": "prism_central"
        }
      }'

# Step 4: Log in to Prism Central and Change its Password
# First, login might require obtaining a session token
loginResponse=$(curl -k -s -X POST "https://$prismCentralIP:9440/api/nutanix/v3/sessions" -H "Content-Type: application/json" -d '{
                                                                            "username": "'$username'",
                                                                            "password": "'$password'"
                                                                          }')

                                                                          # Extract token (Assuming the token field exists in the response. Adjust as necessary.)
                                                                          token=$(echo $loginResponse | jq -r .token)

                                                                          # Change password
                                                                          curl -k -X PUT "https://$prismCentralIP:9440/PrismGateway/services/rest/v1/utils/change_password" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{
                                                                            "oldPassword": "'$password'",
                                                                            "newPassword": "'$newPassword'"
                                                                          }'

# Step 4: Register the Prism Central VM
# Assume you've changed the password and logged in again to obtain a new session token if necessary
# Registration of Prism Central VM might not be directly available or straightforward via API. Adjust as necessary.
# This is a conceptual step to illustrate the process. Check Nutanix's API documentation for specific endpoints and requirements.
curl -k -X POST "https://$prismCentralIP:9440/api/nutanix/v3/prism_central/register" \
-H "Authorization: Bearer $token" \
-H "Content-Type: application/json" -d '{
                                         "prismCentralIP": "'$prismCentralIP'",
                                         "username": "'$username'",
                                         "password": "'$newPassword'"
                                       }'

                                       # Step 5: Configure Prism Central
                                       # Add Name Servers
                                       curl -k -X POST "https://$prismCentralIP:9440/api/nutanix/v3/name_servers" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{
                                         "nameServers": ["1.1.1.1", "8.8.8.8"]
                                       }'

                                       # Add NTP Servers
                                       curl -k -X POST "https://$prismCentralIP:9440/api/nutanix/v3/ntp_servers" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{
                                         "ntpServers": ["0.north-america.pool.ntp.org"]
                                       }'

                                       echo "Configuration steps completed. Verify setup on Prism Central UI."