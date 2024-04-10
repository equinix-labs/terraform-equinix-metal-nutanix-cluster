#!/bin/sh
#
# Script to download and install foundation vm onto a centos server

set -eo pipefail

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

FOUNDATION_DISK_URL="${FOUNDATION_URL:-${REPO_BASE_URL}/test-suite/foundation/Foundation_VM-5.1-disk-0.qcow2}"
FOUNDATION_MEMORY_MB=${FOUNDATION_MEMORY_MB:-4096}
FOUNDATION_MAC="${FOUNDATION_MAC:-52:54:00:be:ef:02}"

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

	log "Installing foundation"
	simple_vm "foundation" "$FOUNDATION_MEMORY_MB" "$FOUNDATION_DISK_URL" "$FOUNDATION_PORT_FORWARD_IN_IFACE" "$FOUNDATION_PORT_FORWARDS" \
		--network bridge=br0,mac="$FOUNDATION_MAC"

	log 'Installation complete!'
}

main
