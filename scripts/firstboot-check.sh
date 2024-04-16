#!/bin/sh

until [ -e /root/.firstboot_success ]
do
	sleep 5
done