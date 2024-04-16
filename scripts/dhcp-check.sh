#!/bin/sh

#TODO: change the ip address and -ge # to be templated fields
until [ "$(arp -a | grep "192.168.100" -c)" -ge 2 ]
do
        sleep 5
done