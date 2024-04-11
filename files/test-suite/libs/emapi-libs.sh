#!/bin/sh
set -e

EMAPI_BASE="${EMAPI_BASE:-https://api.equinix.com}"
EMAPI_BASE_URL="${EMAPI_BASE_URL:-${EMAPI_BASE}/metal/v1}"
EMAPI_METADATA_BASE_URL="${EMAPI_METADATA_BASE_URL:-https://metadata.platformequinix.com}"

alias emapi="curl -sf -H 'X-Auth-Token: $EMAPI_AUTH_TOKEN' -H 'Content-Type: application/json'"

emapi_log() {
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") EMAPI:" "$@" | tee -a /root/emapi.log >&2
}

emapi_install_deps() {
	yum -y install curl epel-release
	yum -y install jq
}

emapi_get_device_id() {
	curl -s "${EMAPI_METADATA_BASE_URL}/2009-04-04/meta-data/instance-id"
}

emapi_get_device_required_data() {
	local device_id="$1"
	shift
	local bond_port_name="${1:-bond0}"

	emapi "${EMAPI_BASE_URL}/devices/${device_id}?include=project_lite" |
		jq -r "[.project_lite.id, .metro.code, (.network_ports | map(select(.name == \"$bond_port_name\") | .id) | last)] | @tsv"
}

emapi_find_vlan() {
	local project_id="$1"
	shift
	local metro_code="$1"
	shift
	local description="$1"

	emapi "${EMAPI_BASE_URL}/projects/${project_id}/virtual-networks" |
		jq -r ".virtual_networks[] |
                select(.description == \"$description\") |
                select(.metro_code == \"$metro_code\")
        "
}

emapi_create_vlan() {
	local project_id="$1"
	shift
	local metro_code="$1"
	shift
	local description="$1"

	create_vlan_payload="$(
		cat <<EOF
{
    "project_id": "$project_id",
    "description": "$description",
    "metro": "$metro_code"
}
EOF
	)"

	emapi -X POST "${EMAPI_BASE_URL}/projects/${project_id}/virtual-networks" -d "$create_vlan_payload"
}

emapi_assign_vlan() {
	local port_id="$1"
	shift
	local vlan_id="$1"

	# Assigning vlan to bond
	assign_vlan_payload="$(
		cat <<EOF
{
    "id": "$port_id",
    "vnid": "$vlan_id"
}
EOF
	)"

	emapi -X POST "${EMAPI_BASE_URL}/ports/${port_id}/assign" -d "$assign_vlan_payload"
}

emapi_device_is_hybrid() {
	local device_id="$1"
	local bond_port_name="$2"
	local bond_net_type=$(emapi "${EMAPI_BASE_URL}/devices/${device_id}?include=project_lite" |
		jq -r ".network_ports | map(select(.name == \"$bond_port_name\")) | last | .network_type")

	test "$bond_net_type" = "hybrid-bonded"
}

emapi_get_hybrid_vlan() {
	local device_id="$1"
	local bond_port_name="$2"
	local bond_hybrid_net_href=$(emapi "${EMAPI_BASE_URL}/devices/${device_id}?include=project_lite" |
		jq -r ".network_ports | map(select(.name == \"$bond_port_name\")) | last | .virtual_networks | last | .href")
	emapi "${EMAPI_BASE}${bond_hybrid_net_href}" | jq -r '.vxlan'
}

emapi_device_to_hybrid_networking() {
	local device_id="$1"
	shift
	local vlan_description="${1:-test l2 vlan}"
	local bond_port_name="$2"

	local device_project_id
	local device_metro
	local device_bond_port_id
	local vlan_id
	local vlan_vxlan

	read -r \
		device_project_id \
		device_metro \
		device_bond_port_id \
		<<<"$(emapi_get_device_required_data "$device_id" "$bond_port_name")"

	emapi_log "Checking if vlan for $vlan_description in $device_metro metro exists..."
	read -r \
		vlan_id \
		vlan_vxlan \
		<<<"$(emapi_find_vlan "$device_project_id" "$device_metro" "$vlan_description" | jq -r '[.id, .vxlan] | @tsv')"

	if [ -z "$vlan_id" ]; then
		emapi_log "Creating a vlan for $vlan_description in $device_metro metro"

		read -r \
			vlan_id \
			vlan_vxlan \
			<<<"$(emapi_create_vlan "$device_project_id" "$device_metro" "$vlan_description" | jq -r '[.id, .vxlan] | @tsv')"
	fi

	emapi_log "Assigning vlan ($vlan_id) to bond port ($device_bond_port_id)"
	if ! emapi_assign_vlan "$device_bond_port_id" "$vlan_id" >/dev/null; then
		emapi_log "Failed to convert to hybrid mode"
		return 1
	fi

	emapi_log "Instance is now in hybrid mode"
	echo "$vlan_vxlan"
}

emapi_create_vlan_iface() {
	local iface="$1"

	cat <<EOF | tee "/etc/sysconfig/network-scripts/ifcfg-${iface}"
DEVICE=$iface
BOOTPROTO=none
ONBOOT=yes
VLAN=yes
EOF
}

emapi_create_bridge_iface() {
	local bridge="$1"
	shift
	local assign_ip="$1"
	shift

	local ip
	local prefix

	local apply_ip

	if [ -n "$assign_ip" ]; then
		IFS='/' read -r ip prefix <<<"$assign_ip"

		apply_ip="$(
			cat <<EOF
IPADDR=$ip
PREFIX=$prefix
EOF
		)"
	fi

	cat <<EOF | tee "/etc/sysconfig/network-scripts/ifcfg-${bridge}"
DEVICE=$bridge
BOOTPROTO=none
ONBOOT=yes
TYPE="Bridge"
$apply_ip
EOF

	for iface in "$@"; do
		echo "BRIDGE=$bridge" >>"/etc/sysconfig/network-scripts/ifcfg-$iface"
	done
}
