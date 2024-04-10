#!/bin/sh
#
# Script to download and install nutanix vms onto a centos server

set -eo pipefail

export REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

export METIS_MAC="${METIS_MAC:-52:54:00:be:ef:11}"
export METIS_IP="${METIS_IP:-192.168.0.11}"
export FOUNDATION_MAC="${FOUNDATION_MAC:-52:54:00:be:ef:12}"
export FOUNDATION_IP="${FOUNDATION_IP:-192.168.0.12}"
export XRAY_MAC="${XRAY_MAC:-52:54:00:be:ef:13}"
export XRAY_IP="${XRAY_IP:-192.168.0.13}"

export L2GATEWAY_CONFIG_DHCP_RANGE="${L2GATEWAY_CONFIG_DHCP_RANGE:-192.168.0.100,192.168.0.254}"
export L2GATEWAY_CONFIG_INTERNAL_IP="${L2GATEWAY_CONFIG_INTERNAL_IP:-192.168.0.1}"

# Forward WAN -> l2gateway
L2GATEWAY_PORT_FORWARDS="l2gw:lease-api=80:80"
L2GATEWAY_PORT_FORWARDS+=",metis:http=8001:8001"
L2GATEWAY_PORT_FORWARDS+=",metis:ssh=2201:2201"
L2GATEWAY_PORT_FORWARDS+=",foundation:http=8002:8002"
L2GATEWAY_PORT_FORWARDS+=",foundation:ssh=2202:2202"
L2GATEWAY_PORT_FORWARDS+=",xray:http=8003:8003"
L2GATEWAY_PORT_FORWARDS+=",xray:ssh=2203:2203"
export L2GATEWAY_PORT_FORWARDS

L2GATEWAY_CONFIG_STATIC_LEASES="${METIS_MAC}=${METIS_IP}"
L2GATEWAY_CONFIG_STATIC_LEASES+=",${FOUNDATION_MAC}=${FOUNDATION_IP}"
L2GATEWAY_CONFIG_STATIC_LEASES+=",${XRAY_MAC}=${XRAY_IP}"
export L2GATEWAY_CONFIG_STATIC_LEASES

# Forward l2gateway -> private vm
L2GATEWAY_CONFIG_PORT_FORWARDS="metis:http=8001:${METIS_IP}:80"
L2GATEWAY_CONFIG_PORT_FORWARDS+=",metis:ssh=2201:${METIS_IP}:22"
L2GATEWAY_CONFIG_PORT_FORWARDS+=",foundation:http=8002:${FOUNDATION_IP}:8000"
L2GATEWAY_CONFIG_PORT_FORWARDS+=",foundation:ssh=2202:${FOUNDATION_IP}:22"
L2GATEWAY_CONFIG_PORT_FORWARDS+=",xray:http=8003:${XRAY_IP}:443"
L2GATEWAY_CONFIG_PORT_FORWARDS+=",xray:ssh=2203:${XRAY_IP}:22"
export L2GATEWAY_CONFIG_PORT_FORWARDS

main() {
	echo "Initializing dhcp installer..." >&2
	curl "$REPO_BASE_URL/test-suite/l2gateway/install.sh" | sh 2>&1 | tee /root/install-l2gateway.log

	echo "Initializing metis installer..." >&2
	curl "$REPO_BASE_URL/test-suite/metis/install.sh" | sh 2>&1 | tee /root/install-metis.log

	echo "Initializing foundation installer..." >&2
	curl "$REPO_BASE_URL/test-suite/foundation/install.sh" | sh 2>&1 | tee /root/install-foundation.log

	echo "Initializing x-ray installer..." >&2
	curl "$REPO_BASE_URL/test-suite/x-ray/install.sh" | sh 2>&1 | tee /root/install-x-ray.log
}

main
