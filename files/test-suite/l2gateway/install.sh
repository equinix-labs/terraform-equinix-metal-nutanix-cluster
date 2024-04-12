#!/bin/sh
#
# Script to download and install metis vm onto a centos server

set -eo pipefail

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

if [ -z "$EMAPI_AUTH_TOKEN" ]; then
	echo "EMAPI_AUTH_TOKEN environment variable missing" >&2
	exit 1
fi

L2GATEWAY_HOST_BOND_IFACE="${L2GATEWAY_HOST_BOND_IFACE:-bond0}"
L2GATEWAY_HOST_L2_IFACE_FORMAT="${L2GATEWAY_HOST_L2_IFACE_FORMAT:-${L2GATEWAY_HOST_BOND_IFACE}.\$VLAN}"
L2GATEWAY_HOST_BRIDGE_IFACE="${L2GATEWAY_HOST_BRIDGE_IFACE:-br0}"
L2GATEWAY_HOST_BRIDGE_IP="${L2GATEWAY_HOST_BRIDGE_IP:-192.168.0.2/24}"
L2GATEWAY_MEMORY_MB=${L2GATEWAY_MEMORY_MB:-4096}
L2GATEWAY_LOCATION_URL="${L2GATEWAY_URL:-https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/}"
L2GATEWAY_KICKSTART_URL="${L2GATEWAY_KICKSTART_URL:-${REPO_BASE_URL}/test-suite/l2gateway/install-vm.ks}"
L2GATEWAY_VM_EXTRA_ARGS="${L2GATEWAY_VM_ARGS:-ks=$L2GATEWAY_KICKSTART_URL}"
L2GATEWAY_VM_DISK_SIZE="${L2GATEWAY_VM_DISK_SIZE:-20}"
L2GATEWAY_PORT_FORWARDS="$L2GATEWAY_PORT_FORWARDS"
L2GATEWAY_VLAN_DESCRIPTION="${L2GATEWAY_VLAN_DESCRIPTION:-nutanix undefined vlan description}"

export L2GATEWAY_CONFIG_INSTALL_SERVICE_URL="${L2GATEWAY_CONFIG_INSTALL_SERVICE_URL:-${REPO_BASE_URL}/test-suite/l2gateway/install-services.sh}"

init_libs() {
	if ! [ -e "/tmp/notanix-libs.sh" ]; then
		# Initialize notanix libs
		curl "${REPO_BASE_URL}/test-suite/libs/notanix-libs.sh" >/tmp/notanix-libs.sh
	fi
	source /tmp/notanix-libs.sh

	if ! [ -e "/tmp/emapi-libs.sh" ]; then
		# Initialize emapi libs
		curl "${REPO_BASE_URL}/test-suite/libs/emapi-libs.sh" >/tmp/emapi-libs.sh
	fi
	source /tmp/emapi-libs.sh
}

main() {
	init_libs
	init_prereqs

	emapi_install_deps
	local device_id="$(emapi_get_device_id)"

	log "Converting host ${device_id} to hybrid networking"
	local vlan="$(emapi_device_to_hybrid_networking "$device_id" "$L2GATEWAY_VLAN_DESCRIPTION" "$L2GATEWAY_HOST_BOND_IFACE")"
	if ( ($? != 0)); then
		return 1
	fi

	local l2_iface="$(echo "$L2GATEWAY_HOST_L2_IFACE_FORMAT" | VLAN="$vlan" envsubst '$VLAN')"

	log "Creating vlan and bridge interfaces"
	emapi_create_vlan_iface "$l2_iface"
	emapi_create_bridge_iface "$L2GATEWAY_HOST_BRIDGE_IFACE" "$L2GATEWAY_HOST_BRIDGE_IP" "$l2_iface"

	log "Reloading interface configs"

	nmcli connection reload

	log "Bringing up interfaces"

	while ! ip link show "$L2GATEWAY_HOST_BRIDGE_IFACE"; do
		log "Waiting for bridge interface ($L2GATEWAY_HOST_BRIDGE_IFACE) to become available"
		sleep 1
	done

	ip link set "$L2GATEWAY_HOST_BRIDGE_IFACE" up

	while ! ip link show "$l2_iface"; do
		log "Waiting for layer 2 interface ($l2_iface) to become available"
		sleep 1
	done

	ip link set "$l2_iface" up

	log "Installing L2 Gateway"
	install_vm "l2gateway" "$L2GATEWAY_MEMORY_MB" "$L2GATEWAY_VM_DISK_SIZE" "$L2GATEWAY_HOST_BOND_IFACE" "$L2GATEWAY_PORT_FORWARDS" \
		--location "$L2GATEWAY_LOCATION_URL" \
		--extra-args "$L2GATEWAY_VM_EXTRA_ARGS $(env_to_args "L2GATEWAY_CONFIG" "l2gateway")" \
		--network bridge=virbr0 \
		--network bridge="$L2GATEWAY_HOST_BRIDGE_IFACE"

	log "Waiting for OS to complete installation"

	if ! vm_wait_for_state "l2gateway" "shutoff" 10; then
		log "l2gateway never shutdown after installation."
		return 1
	fi

	# VM Shuts down after install (not sure why) but worked out for testing when the os has completed installation
	virsh start l2gateway

	# After the install-l2gateway.service completes installing, it powers down so we can block until that's complete

	log "Waiting for l2gateway services to be installed"

	if ! vm_wait_for_state "l2gateway" "shutoff" 10; then
		log "l2gateway never shutdown after service installation."
		return 1
	fi

	virsh start l2gateway

	# Give the vm some time to start so dhcp is ready for any other containers
	sleep 5

	log 'Installation complete!'
}

main
