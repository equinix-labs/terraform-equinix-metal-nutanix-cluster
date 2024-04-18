#!/bin/sh

IPADDRS=$(awk '/CVM/ { if (ips != "") ips = ips ","; ips = ips $3 } END { print ips }' /var/lib/misc/dnsmasq.leases)
SSH_HOST=$(echo "$IPADDRS" | cut -f1 -d',')
sshpass -p "Nutanix.123" ssh -t admin@"$SSH_HOST" "echo \"Nutanix.123\" | sudo -S cluster --skip_discovery -s $IPADDRS create"