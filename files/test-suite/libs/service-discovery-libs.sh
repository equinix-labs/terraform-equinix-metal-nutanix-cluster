#!/bin/sh

SD_INIT_PREREQS_MARKER_FILE="/tmp/service-discovery-libs.prereqs.marker"
SD_SSH_DEFAULT_ARGS=(-q -o ConnectTimeout=1 -o ConnectionAttempts=1 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)

sd_log() {
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") Service-Discovery:" "$@" | tee -a /root/service-discovery.log >&2
}

sd_install_deps() {
	yum -y install epel-release
	yum -y install sshpass
}

sd_init_prereqs() {
	if [ -e "$SD_INIT_PREREQS_MARKER_FILE" ]; then
		return 0
	fi

	sd_log "Installing prereqs"

	sd_install_deps

	touch "$SD_INIT_PREREQS_MARKER_FILE"
}

sd_ssh() {
	local ssh_host="$1"
	shift
	local ssh_pass="$1"
	shift

	local ssh_args=()

	if [ -z "${SD_SSH_ARGS}" ]; then
		ssh_args=("${SD_SSH_DEFAULT_ARGS[@]}")
	else
		ssh_args=("${SD_SSH_DEFAULT_ARGS[@]}" "${SD_SSH_ARGS[@]}")
	fi

	if [ -n "$ssh_pass" ]; then
		sshpass -p "$ssh_pass" ssh "$ssh_host" "${ssh_args[@]}" sh "$@"
		return $?
	fi

	ssh "$ssh_host" "${ssh_args[@]}" sh "$@"
}

sd_ssh_vm_domain_list() {
	local ssh_host="$1"
	shift
	local ssh_pass="$1"
	shift
	local grep_domain="$1"
	shift

	cat <<EOF | sd_ssh "$ssh_host" "$ssh_pass"
if [ -n "$grep_domain" ]; then
    virsh list --all --name | grep "$grep_domain"
else
    virsh list --all --name
fi
EOF
}

sd_ssh_vm_domain_iface() {
	local ssh_host="$1"
	shift
	local ssh_pass="$1"
	shift
	local domain="$1"
	shift
	local iface="${1:-vnet0}"

	cat <<EOF | sd_ssh "$ssh_host" "$ssh_pass"
virsh domiflist "$domain" | grep "$iface"
EOF
}

sd_ssh_all_vm_domain_mac() {
	local ssh_host="$1"
	shift
	local ssh_pass="$1"
	shift
	local grep_domain="$1"
	shift
	local grep_iface="${1:-vnet0}"

	local domains="$(sd_ssh_vm_domain_list "$ssh_host" "$ssh_pass" "$grep_domain")"

	for domain in $domains; do
		if [ -z "$domain" ]; then
			continue
		fi

		echo "$domain $(sd_ssh_vm_domain_iface "$ssh_host" "$ssh_pass" "$domain" "$grep_iface")"
	done
}
