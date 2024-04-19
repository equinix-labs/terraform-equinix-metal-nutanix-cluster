#!/bin/sh

# Pick a host to use for cluster creation.
IPADDRS=$(awk '/CVM/ { if (ips != "") ips = ips ","; ips = ips $3 } END { print ips }' /var/lib/misc/dnsmasq.leases)
SSH_HOST=$(echo "$IPADDRS" | cut -f1 -d',')

# Change the CVM password on that host.
expect /root/change-cvm-passwd.exp "$SSH_HOST"

# Create the cluster.
sshpass -p "Nutanix.123" ssh -t -o StrictHostKeyChecking=no admin@"$SSH_HOST" "echo \"Nutanix.123\" | sudo -S cluster --skip_discovery -s $IPADDRS create"
