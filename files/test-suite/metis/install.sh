#!/bin/sh
#
# Script to download and install metis vm onto a centos server

set -eo pipefail

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

METIS_DISK_URL="${METIS_URL:-${REPO_BASE_URL}/test-suite/metis/nutanix-metis-2.8.6-77193790-disk1.qcow2}"
METIS_MEMORY_MB=${METIS_MEMORY_MB:-4096}
METIS_MAC="${METIS_MAC:-52:54:00:be:ef:01}"

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

	log "Installing metis"
	simple_vm "metis" "$METIS_MEMORY_MB" "$METIS_DISK_URL" "$METIS_PORT_FORWARD_IN_IFACE" "$METIS_PORT_FORWARDS" \
		--network bridge=br0,mac="$METIS_MAC"

	log 'Installation complete!'
}

main
