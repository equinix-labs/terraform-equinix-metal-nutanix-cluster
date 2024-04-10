#!/bin/sh

SD_NUTANIX_LOG_FILE="/root/sd-nutanix.log"

LEASE_URL="${LEASE_URL:-http://192.168.0.1/leases}"

IGNORE_MAC_PREFIX="${IGNORE_MAC_PREFIX:-52:54:00:be:ef}"

DEFAULT_NUTANIX_SSH_HOST_USER="${DEFAULT_NUTANIX_SSH_HOST_USER:-root}"
DEFAULT_NUTANIX_SSH_HOST_PASS="${DEFAULT_NUTANIX_SSH_HOST_PASS:-nutanix/4u}"

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

sd_nutanix_log() {
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") [SD] Nutanix:" "$@" | tee -a "$SD_NUTANIX_LOG_FILE" >&2
}

sd_nutanix_init_libs() {
	if ! [ -e "/tmp/service-discovery-libs.sh" ]; then
		# Initialize notanix libs
		curl "${REPO_BASE_URL}/test-suite/libs/service-discovery-libs.sh" >/tmp/service-discovery-libs.sh
	fi
	source /tmp/service-discovery-libs.sh
}

sd_nutanix_init_prereqs() {
	sd_init_prereqs
}

nutanix_get_leases() {
	curl -sf "$LEASE_URL" | grep -v "$IGNORE_MAC_PREFIX"
}

nutanix_test_ssh() {
	local ssh_host="$1"
	shift
	local ssh_pass="$1"

	if sd_ssh "$ssh_host" "$ssh_pass" -c 'whoami' >/dev/null; then
		return 0
	fi

	return 1
}

nutanix_get_hosts() {
	local leases="$(nutanix_get_leases)"

	local lease_mac
	local lease_ip

	for lease in $leases; do
		IFS='=' read -r lease_mac lease_ip <<<"$lease"

		sd_nutanix_log "Testing SSH connection to $lease_ip"

		if nutanix_test_ssh "${DEFAULT_NUTANIX_SSH_HOST_USER}@$lease_ip" "${DEFAULT_NUTANIX_SSH_HOST_PASS}"; then
			sd_nutanix_log "Connection to $lease_ip successful"
			echo "$lease_ip"
		else
			sd_nutanix_log "Connection to $lease_ip failed"
		fi
	done
}

nutanix_get_domain() {
	local host_ip="$1"
	shift
	local domain="$1"

	sd_ssh_vm_domain_list "${DEFAULT_NUTANIX_SSH_HOST_USER}@$host_ip" "${DEFAULT_NUTANIX_SSH_HOST_PASS}" "$domain"
}

nutanix_get_domain_ip() {
	local host_ip="$1"
	shift
	local domain="$1"

	local iface_name
	local iface_type
	local iface_src
	local iface_model
	local iface_mac

	read -r \
		iface_name \
		iface_type \
		iface_src \
		iface_model \
		iface_mac \
		<<<"$(sd_ssh_vm_domain_iface "${DEFAULT_NUTANIX_SSH_HOST_USER}@$host_ip" "${DEFAULT_NUTANIX_SSH_HOST_PASS}" "$domain")"

	sd_nutanix_log "Host: $host_ip discovered iface: name: $iface_name, src: $iface_src, mac: $iface_mac"

	nutanix_get_leases | grep "$iface_mac" | cut -d '=' -f 2
}

nutanix_get_host_cvm_info() {
	local hosts="$(nutanix_get_hosts)"

	sd_nutanix_log "Discovered $(echo "$hosts" | wc -l) hosts"
	sd_nutanix_log "$hosts"

	local domain_suffix="CVM"
	local domain
	local domain_lease

	for host in $hosts; do
		sd_nutanix_log "Host $host: Discovering $domain_suffix domain..."
		domain="$(nutanix_get_domain "$host" "$domain_suffix")"
		if [ -z "$domain" ]; then
			sd_nutanix_log "Host $host: No domain ending with $domain_suffix found"
			continue
		fi

		domain_lease="$(nutanix_get_domain_ip "$host" "$domain")"
		if [ -z "$domain_lease" ]; then
			sd_nutanix_log "Host $host: No lease found for $domain"
			continue
		fi

		sd_nutanix_log "Host $host: $domain_suffix: $domain (ip: $domain_lease)"
		echo "$host,$domain,$domain_lease"
	done
}
