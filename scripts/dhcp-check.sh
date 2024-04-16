#!/bin/sh

until [ "$(arp -a | grep "192.168.100" -c)" -ge 2 ]
do
        sleep 5
done