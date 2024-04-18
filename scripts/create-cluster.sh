#!/bin/sh

IPADDRS=$(awk '/CVM/ { if (ips != "") ips = ips ","; ips = ips $3 } END { print ips }' /var/lib/misc/dnsmasq.leases)
echo $IPADDRS
SSH_HOST=$(echo "$IPADDRS" | cut -f1 -d',')
echo $SSH_HOST
sshpass -p "Nutanix.123" ssh -t -o StrictHostKeyChecking=no admin@"$SSH_HOST" "echo \"Nutanix.123\" | sudo -S cluster --skip_discovery -s $IPADDRS create"