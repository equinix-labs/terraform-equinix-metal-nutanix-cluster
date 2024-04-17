#!/bin/sh

#TODO: change the ip address and -ge # to be templated fields
until [ "$(grep -c "CVM" /var/lib/misc/dnsmasq.leases)" -ge 1 ]
do
        sleep 5
done