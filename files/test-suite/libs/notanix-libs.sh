#!/bin/sh
#
# Functions to setup and deploy vms on a fresh host

set -e

log() {
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") Notanix:" "$@" | tee -a /root/notanix.log >&2
}

setup_iptables() {
	systemctl mask firewalld
	systemctl stop firewalld
	yum -y install iptables-services

	systemctl enable iptables
	systemctl start iptables

	iptables -P INPUT ACCEPT
	iptables -F
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT ACCEPT
	iptables-save >/etc/sysconfig/iptables
}

install_kvm() {
	yum -y install @virt* virt-install xorg-x11-xauth libguestfs-tools policycoreutils-python-utils

	log "Enabling ipv4 forwarding"
	sed -i 's/^\(net.ipv4.ip_forward =\).*/\1 1/' /etc/sysctl.conf
	sysctl -p

	log "Setting up hooks file"
	setup_hooks_file

	log "Starting libvirtd service"
	systemctl enable libvirtd
	systemctl restart libvirtd
}

env_to_args() {
	local env_prefix="$1"
	local rename_prefix="$2"
	local args=()

	while read arg; do
		# Get only variable
		name=${arg%%=*}

		# Rename prefix if requested
		if [ -n "$rename_prefix" ]; then
			name=${name/$env_prefix/$rename_prefix}
		fi

		# Convert _ to -
		name=${name//_/-}
		# Convert to lowercase
		name=${name,,}

		args+=("$name=${arg#*=}")
	done <<<"$(env | grep "^$env_prefix")"

	echo "${args[@]}"
}

get_disk() {
	local url="$1"
	shift
	local path="$1"

	if ! [ -e "$path" ]; then
		log "Downloading $url to $path"
		curl "$url" >"$path"
	fi
}

create_vm() {
	local name="$1"
	shift
	local memory="$1"
	shift
	local disk="$1"
	shift || true

	local disk_format="qcow2"

	if ! (echo "$disk" | grep -q qcow2 || file "$disk" | grep -q QCOW); then
		disk_format="raw"
	fi

	virt-install \
		--os-variant=rhel7-unknown \
		--disk "$disk,format=$disk_format" \
		--boot hd \
		--nographics \
		--vcpus=4 \
		--ram="$memory" \
		--noautoconsole \
		--autostart \
		--name="$name" "$@"
}

vm_wait_for_state() {
	local domain="$1"
	shift
	local state="$1"
	local recheck_delay="${2:-1}"
	local max_attempts="${3:-120}"

	local remaining_attempts=$max_attempts

	while (($remaining_attempts > 0)) && ! virsh list --name "--state-${state}" | grep -q "$domain"; do
		remaining_attempts=$((remaining_attempts - 1))
		echo "$(date) [${remaining_attempts}/${max_attempts}] | $(virsh list | grep "$domain")"
		sleep "$recheck_delay"
	done
	virsh list --name "--state-${state}" | grep -q "$domain"
}

domain_mac_address() {
	local domain="$1"
	shift
	timeout 30s virsh dumpxml "$domain" | grep -B 3 'virbr0' | grep 'mac address' | awk -F "'" '{print $2}'
}

network_mac_ip() {
	local network="$1"
	shift
	local mac="$1"

	timeout 30s virsh net-dhcp-leases "$network" | grep "$mac" | awk -F ' ' '{print $5}' | awk -F '/' '{print $1}'
}

domain_dhcp_ip() {
	local domain="$1"

	local mac="$(domain_mac_address "$domain")"

	network_mac_ip default "$mac"
}

setup_hooks_file() {
	if ! [ -e "/etc/libvirt/hooks/qemu" ]; then
		mkdir -p /etc/libvirt/hooks
		cat <<'EOF' >/etc/libvirt/hooks/qemu
#!/bin/sh

echo "$0" "$@" >> /tmp/notanix.hooks

down_hook(){
    local domain="$1"; shift
    local script="/etc/libvirt/domain-hooks/${domain}.down"

    if [ -x "$script" ]; then
        exec "$script" "$@"
    fi
}

up_hook(){
    local domain="$1"; shift
    local script="/etc/libvirt/domain-hooks/${domain}.up"

    if [ -x "$script" ]; then
        exec "$script" "$@"
    fi
}

main(){
    local domain="$1"; shift
    local action="$1"; shift

    case $action in
        start)
            down_hook "$domain" "$@"
            ;;
        started)
            up_hook "$domain" "$@"
            ;;
        stopped)
            down_hook "$domain" "$@"
            ;;
        *)
            echo "Ignoring action: $action" >&2
            ;;
    esac
}

main "$@"
EOF
		chmod +x /etc/libvirt/hooks/qemu
	fi

	mkdir -p /etc/libvirt/domain-hooks
}

iptables_down() {
	local domain="$1"
	shift
	local lease_ip="$1"
	shift
	local svc="$1"
	shift
	local src_iface="$1"
	shift
	local src_port="$1"
	shift
	local dst_port="$1"
	local comment="$domain IN $svc"

	if [ -n "$src_iface" ]; then
		src_iface="-i \"$src_iface\""
	fi

	local script="/etc/libvirt/domain-hooks/${domain}.down"

	if ! [ -e "$script" ]; then
		cat <<EOF >"$script"
#!/bin/sh
set -e
EOF
	fi

	cat <<EOF | tee -a "$script" | sh
iptables -D FORWARD -o virbr0 -d "$lease_ip" -m comment --comment "$comment" -j ACCEPT 2>/dev/null || true
iptables -t nat -D PREROUTING $src_iface -p tcp --dport "$src_port" -j DNAT --to "${lease_ip}:${dst_port}" -m comment --comment "$comment" 2>/dev/null || true
EOF
	chmod +x "$script"
}

iptables_up() {
	local domain="$1"
	shift
	local lease_ip="$1"
	shift
	local svc="$1"
	shift
	local src_iface="$1"
	shift
	local src_port="$1"
	shift
	local dst_port="$1"
	local comment="$domain IN $svc"

	if [ -n "$src_iface" ]; then
		src_iface="-i \"$src_iface\""
	fi

	local script="/etc/libvirt/domain-hooks/${domain}.up"

	if ! [ -e "$script" ]; then
		cat <<EOF >"$script"
#!/bin/sh
set -e
EOF
	fi

	cat <<EOF | tee -a "$script" | sh
iptables -I FORWARD -o virbr0 -d "$lease_ip" -m comment --comment "$comment" -j ACCEPT
iptables -t nat -I PREROUTING $src_iface -p tcp --dport "$src_port" -j DNAT --to "${lease_ip}:${dst_port}" -m comment --comment "$comment"
EOF
	chmod +x "$script"
}

get_domain_dhcp_ip() {
	local domain="$1"
	local lease_ip="$(domain_dhcp_ip "$domain")"

	local tries_remaining=120

	while (($tries_remaining > 0)) && [ -z "$lease_ip" ]; do
		tries_remaining=$((tries_remaining - 1))
		log "Waiting for $domain to get an ip... (tries remaining: $tries_remaining)"
		sleep 30
		lease_ip="$(domain_dhcp_ip "$domain")"
	done

	if [ -z "$lease_ip" ]; then
		log "$domain has no ip"
		return 1
	fi

	log "$domain has ip: $lease_ip"

	echo "$lease_ip"
	return 0
}

add_vm() {
	local domain="$1"
	shift
	local memory_mb="$1"
	shift
	local disk_url="$1"
	shift || true

	local disk_image_path="/var/lib/libvirt/images/${domain}.qcow2"

	get_disk "$disk_url" "$disk_image_path"

	create_vm "$domain" "$memory_mb" "$disk_image_path" "$@"
}

add_port_forwards() {
	local domain="$1"
	shift
	local service="$1"
	shift
	local src_iface="$1"
	shift
	local src_port="$1"
	shift
	local dst_port="$1"

	local lease_ip="$(get_domain_dhcp_ip "$domain")"

	if [ -z "$lease_ip" ]; then
		return 1
	fi

	iptables_down "$domain" "$lease_ip" "$service" "$src_iface" "$src_port" "$dst_port"
	iptables_up "$domain" "$lease_ip" "$service" "$src_iface" "$src_port" "$dst_port"
}

simple_vm() {
	local domain="$1"
	shift
	local memory="$1"
	shift
	local disk_url="$1"
	shift
	local src_iface="$1"
	shift || true
	local port_forwards="$1"
	shift || true

	log "Installing $domain vm"
	add_vm "$domain" "$memory" "$disk_url" "$@"

	while [ -n "$port_forwards" ]; do
		IFS=',' read -r pfcfg port_forwards <<<"$port_forwards"
		IFS='=' read -r service ports <<<"$pfcfg"
		IFS=':' read -r src_port dst_port <<<"$ports"

		log "Forwarding $src_iface:$src_port to ${domain}:$dst_port ($service)"
		add_port_forwards "$domain" "$service" "$src_iface" "$src_port" "$dst_port"
	done
}

install_vm() {
	local domain="$1"
	shift
	local memory="$1"
	shift
	local disk_size="$1"
	shift
	local src_iface="$1"
	shift || true
	local port_forwards="$1"
	shift || true

	local disk_image_path="/var/lib/libvirt/images/${domain}.qcow2,size=$disk_size"

	log "Installing $domain vm"
	create_vm "$domain" "$memory" "$disk_image_path" "$@"

	while [ -n "$port_forwards" ]; do
		IFS=',' read -r pfcfg port_forwards <<<"$port_forwards"
		IFS='=' read -r service ports <<<"$pfcfg"
		IFS=':' read -r src_port dst_port <<<"$ports"

		log "Forwarding $src_iface:$src_port to ${domain}:$dst_port ($service)"
		add_port_forwards "$domain" "$service" "$src_iface" "$src_port" "$dst_port"
	done
}

init_prereqs() {
	if [ -e "/tmp/notanix.prereqs.marker" ]; then
		return 0
	fi
	log "Installing prereqs"

	log "Updating ca certificates"
	yum -y install ca-certificates

	log "Ensuring NetworkManager installed and active"
	yum -y install NetworkManager
	systemctl enable NetworkManager
	systemctl start NetworkManager

	log "Setting up iptables"
	setup_iptables

	log "Installing kvm"
	install_kvm

	touch /tmp/notanix.prereqs.marker
}
