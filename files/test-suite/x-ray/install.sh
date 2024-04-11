#!/bin/sh
#
# Script to download and install xray vm onto a centos server

set -eo pipefail

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

XRAY_DISK_URL="${XRAY_URL:-${REPO_BASE_URL}/test-suite/x-ray/xray-4.3.1.qcow2}"
XRAY_MEMORY_MB=${XRAY_MEMORY_MB:-4096}
XRAY_MAC="${XRAY_MAC:-52:54:00:be:ef:03}"

init_libs() {
	if ! [ -e "/tmp/notanix-libs.sh" ]; then
		# Initialize notanix libs
		curl "${REPO_BASE_URL}/test-suite/libs/notanix-libs.sh" >/tmp/notanix-libs.sh
	fi
	source /tmp/notanix-libs.sh
}

main() {
	init_libs
	init_prereqs

	log "Installing x-ray"
	simple_vm "x-ray" "$XRAY_MEMORY_MB" "$XRAY_DISK_URL" "$XRAY_PORT_FORWARD_IN_IFACE" "$XRAY_PORT_FORWARDS" \
		--network bridge=br0,mac="$XRAY_MAC"

	log 'Installation complete!'
}

main
