#!/bin/sh

SSH_KEY_PATH="${SSH_KEY_PATH:-/home/nutanix/.ssh/id_rsa}"

NUTANIX_SSH_OPTS=(-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)
NUTANIX_SSH_PASS="${NUTANIX_SSH_PASS:-nutanix/4u}"

REPO_BASE_URL="${REPO_BASE_URL:-https://artifacts.platformequinix.com/vendors/nutanix}"

log() {
	echo "$(date) run-test-prereqs: $@" >&2
}

init_libs() {
	if ! [ -e "/tmp/sd-nutanix-libs.sh" ]; then
		# Initialize notanix libs
		curl "${REPO_BASE_URL}/test-suite/libs/sd-nutanix-libs.sh" >/tmp/sd-nutanix-libs.sh
	fi
	source /tmp/sd-nutanix-libs.sh

	sd_nutanix_init_libs
}

init_prereqs() {
	sd_nutanix_init_prereqs

	yum -y install epel-release
	yum -y install sshpass
}

create_ssh_key() {
	local key_dir="$(dirname "$SSH_KEY_PATH")"

	mkdir -p "$key_dir"
	chmod 700 "$key_dir"

	if ! [ -e "$SSH_KEY_PATH" ]; then
		ssh-keygen -t rsa -N "" -f "$SSH_KEY_PATH"

		log "RSA SSH Key created:"
	else
		log "Reusing existing ssh key:"
	fi

	cat "$SSH_KEY_PATH"
}

ssh_copy_id_host() {
	local host="$1"
	shift
	local homedir="$1"
	shift
	local pub_key_file="$1"

	local ssh_pub_key="$(cat "$pub_key_file")"

	cat <<EOF | sshpass -p "$NUTANIX_SSH_PASS" ssh "${NUTANIX_SSH_OPTS[@]}" "${host}" sh -x
mkdir -p ${homedir}/.ssh
echo "$ssh_pub_key" >> ${homedir}/.ssh/authorized_keys
echo "$ssh_pub_key" >> ${homedir}/.ssh/authorized_keys2
chmod 700 ${homedir}/.ssh
chmod 600 ${homedir}/.ssh/authorized_keys
chmod 600 ${homedir}/.ssh/authorized_keys2
EOF
}

initialize_nutanix_cluster() {
	local cvm_ips="$1"

	if [ -n "$MIN_CLUSTER_SIZE" ]; then
		local cluster_size="$(($(echo "$cvm_ips" | grep -o ',' | wc -l) + 1))"

		if (($cluster_size < $MIN_CLUSTER_SIZE)); then
			log "Cluster does not meet minimum requirements: $cluster_size < $MIN_CLUSTER_SIZE"
			return false
		fi
	fi

	local first_cvm_ip
	local other_ips

	IFS=',' read -r first_cvm_ip other_ips <<<"$cvm_ips"

	log "Creating cluster with $cvm_ips on $first_cvm_ip"
	cat <<EOF | sshpass -p "$NUTANIX_SSH_PASS" ssh "${NUTANIX_SSH_OPTS[@]}" "nutanix@${first_cvm_ip}" sh
/usr/local/nutanix/cluster/bin/cluster -s "$cvm_ips" create
EOF
}

main() {
	init_libs
	init_prereqs

	sd_nutanix_log "Determining CVM ips..."

	local host_cvm_assoc="$(nutanix_get_host_cvm_info)"

	if [ -z "$host_cvm_assoc" ]; then
		log "No hosts found"
		exit 1
	fi

	local cvm_ips=""

	for leases in $host_cvm_assoc; do
		IFS=',' read -r host_ip cvm_name cvm_ip <<<"$leases"

		if [ -z "$cvm_ips" ]; then
			cvm_ips="$cvm_ip"
		else
			cvm_ips+=",$cvm_ip"
		fi

		log "Found: Host IP: $host_ip CVM: $cvm_name CVM IP: $cvm_ip"

		if [ "$SINGLE_NODE_CLUSTERS" == "true" ]; then
			log "SINGLE_NODE_CLUSTERS is defined. Initializing Host IP: $host_ip CVM: $cvm_name CVM IP: $cvm_ip"
			initialize_nutanix_cluster "$cvm_ip" &
		fi
	done

	if [ "$SINGLE_NODE_CLUSTERS" == "true" ]; then
		log "Waiting for clusters to initialize"

		wait
	else
		log "Initializing cluster"
		initialize_nutanix_cluster "$cvm_ips"
	fi

	log "Creating SSH key..."

	create_ssh_key

	log "Installing ssh keys on hosts..."

	for leases in $host_cvm_assoc; do
		IFS=',' read -r host_ip cvm_name cvm_ip <<<"$leases"

		echo "Host IP: $host_ip CVM: $cvm_name CVM IP: $cvm_ip"

		ssh_copy_id_host "root@$host_ip" "/root" "${SSH_KEY_PATH}.pub"
		ssh_copy_id_host "nutanix@$cvm_ip" "/home/nutanix" "${SSH_KEY_PATH}.pub"
	done

	echo "--- Configuration ---"
	echo "SSH Key:"
	cat "$SSH_KEY_PATH"
	echo ""
	echo "Leases:"
	echo -e "Host IP\t\tCVM Name\t\tCVM IP"
	for leases in $host_cvm_assoc; do
		echo "$leases" | tr ',' '\t'
	done
}

if [ -z "$1" ]; then
	echo "Cluster mode required: single or multi" >&2
	exit 1
fi

case "$1" in
single)
	export SINGLE_NODE_CLUSTERS="true"
	;;
multi)
	export SINGLE_NODE_CLUSTERS="false"
	;;
*)
	echo "Cluster mode required: single or multi" >&2
	exit 1
	;;
esac

main
