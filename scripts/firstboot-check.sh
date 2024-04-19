#!/bin/sh

# Timeout in seconds (30 minutes)
timeout=1800

counter=0
until [ -e /root/.firstboot_success ] || [ "$counter" -ge "$timeout" ]; do
	sleep 5
	counter=$((counter + 5))
done

if [ "$counter" -ge "$timeout" ]; then
	echo "Timeout reached waiting for the firstboot of the node to succeed."
	exit 1
fi

echo "Firstboot succeeded!"
