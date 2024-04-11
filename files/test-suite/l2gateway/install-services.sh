#!/bin/sh
#
# Setup and run a linux nat gateway server
set -e

export L2GATEWAY_DHCP_RANGE="${L2GATEWAY_DHCP_RANGE:-192.168.0.10,192.168.0.254}"
export L2GATEWAY_EXTERNAL_IFACE="${L2GATEWAY_EXTERNAL_IFACE:-ens3}"
export L2GATEWAY_INTERNAL_IP="${L2GATEWAY_INTERNAL_IP:-192.168.0.1}"
export L2GATEWAY_INTERNAL_PREFIX="${L2GATEWAY_INTERNAL_PREFIX:-24}"
export L2GATEWAY_INTERNAL_IFACE="${L2GATEWAY_INTERNAL_IFACE:-ens4}"
export L2GATEWAY_INTERNAL_DNS1="${L2GATEWAY_INTERNAL_DNS1:-147.75.207.207}"
export L2GATEWAY_INTERNAL_DNS2="${L2GATEWAY_INTERNAL_DNS1:-147.75.207.208}"

log() {
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") $@" | tee -a /root/install-gateway.log >&2
}

setup_iptables() {
	log "Replacing firewalld with iptables"
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

configure_internal_iface() {
	log "Configuring $L2GATEWAY_INTERNAL_IFACE as internal interface"

	ip link set "$L2GATEWAY_INTERNAL_IFACE" down || true

	cat <<EOF | tee "/etc/sysconfig/network-scripts/ifcfg-${L2GATEWAY_INTERNAL_IFACE}"
NAME=${L2GATEWAY_INTERNAL_IFACE}
DEVICE=${L2GATEWAY_INTERNAL_IFACE}
TYPE=Ethernet
BOOTPROTO=static
IPADDR=${L2GATEWAY_INTERNAL_IP}
PREFIX=${L2GATEWAY_INTERNAL_PREFIX}
DEFROUTE=no
ONBOOT=yes
EOF

	ip link set "$L2GATEWAY_INTERNAL_IFACE" up
}

install_dnsmasq() {
	log "Installing dnsmasq"
	yum -y install dnsmasq
	cat <<EOF | tee /etc/dnsmasq.d/internal.conf
dhcp-range=${L2GATEWAY_DHCP_RANGE},24h
listen-address=${L2GATEWAY_INTERNAL_IP}
interface=${L2GATEWAY_INTERNAL_IFACE}
server=${L2GATEWAY_INTERNAL_DNS1}
server=${L2GATEWAY_INTERNAL_DNS2}
dhcp-option=option:router,${L2GATEWAY_INTERNAL_IP}
dhcp-option=option:dns-server,${L2GATEWAY_INTERNAL_IP}
EOF
	systemctl enable dnsmasq
	systemctl start dnsmasq

	log "Setting up dhcp and dns iptables rules"
	iptables -I INPUT -p udp --dport 53 -m comment --comment "Allow DNS" -j ACCEPT
	iptables -I INPUT -p udp --dport 67 -m comment --comment "Allow DHCP" -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
}

setup_static_leases() {
	log "Setting up static dhcp leases"

	local static_leases="$L2GATEWAY_STATIC_LEASES"

	while [ -n "$static_leases" ]; do
		IFS=',' read -r slcfg static_leases <<<"$static_leases"
		IFS='=' read -r mac_addr ip_addr <<<"$slcfg"

		comment="$service IN $src_port:$dst_ip:$dst_port"

		log "Setting static ip for $mac_addr to $ip_addr"
		echo "dhcp-host=${mac_addr},${ip_addr}" >>/etc/dnsmasq.d/static-leases.conf
	done
}

install_lease_api() {
	log "Installing lease api"

	yum -y install epel-release
	yum -y install nginx
	cat <<'EOF' | tee /bin/update-leases
#!/bin/sh

OUT_FILE="$1"; shift
sleep_seconds="${1:-5}"

LEASE_FILE="${LEASE_FILE:-/var/lib/dnsmasq/dnsmasq.leases}"

if [ -z "$OUT_FILE" ]; then
    echo "$0 OUT_FILE [REFRESH_DELAY]" 2>&1
    exit 1
fi

while true; do
    awk -F ' ' '{print $2"="$3}' "$LEASE_FILE" | tee "$OUT_FILE"
    sleep "$sleep_seconds"
done
EOF
	chmod +x /bin/update-leases

	cat <<EOF | tee /usr/lib/systemd/system/watch-leases.service
[Unit]
Description=Watch dnsmasq leases and expose them over http endpoint
After=network-online.target

[Service]
ExecStart=/bin/update-leases "/usr/share/nginx/html/leases"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
	systemctl enable watch-leases
	systemctl start watch-leases

	systemctl enable nginx
	systemctl start nginx

	log "Setting up http iptables rules"
	iptables -I INPUT -p tcp --dport 80 -m comment --comment "Allow HTTP" -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
}

install_nat() {
	log "Enabling ipv4 forwarding"
	echo 'net.ipv4.ip_forward = 1' >>/etc/sysctl.conf
	sysctl -p

	log "Setting up nat iptables rules"
	iptables -t nat -A POSTROUTING -o "$L2GATEWAY_EXTERNAL_IFACE" -j MASQUERADE
	iptables -A FORWARD -i "$L2GATEWAY_EXTERNAL_IFACE" -o "$L2GATEWAY_INTERNAL_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i "$L2GATEWAY_INTERNAL_IFACE" -o "$L2GATEWAY_EXTERNAL_IFACE" -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
}

setup_port_forwards() {
	log "Setting up port forwarding"

	local port_forwards="$L2GATEWAY_PORT_FORWARDS"
	local comment=""

	while [ -n "$port_forwards" ]; do
		IFS=',' read -r pfcfg port_forwards <<<"$port_forwards"
		IFS='=' read -r service ports <<<"$pfcfg"
		IFS=':' read -r src_port dst_ip dst_port <<<"$ports"

		comment="$service IN $src_port:$dst_ip:$dst_port"

		log "Forwarding $comment"
		iptables -I FORWARD -o ${L2GATEWAY_INTERNAL_IFACE} -d "$dst_ip" -m comment --comment "$comment" -j ACCEPT
		iptables -t nat -I PREROUTING -p tcp --dport "$src_port" -j DNAT --to "${dst_ip}:${dst_port}" -m comment --comment "$comment"
	done

	if [ -n "$L2GATEWAY_PORT_FORWARDS" ]; then
		iptables-save >/etc/sysconfig/iptables
	fi
}

main() {
	log "Setting up gateway server..."

	setup_iptables

	configure_internal_iface

	install_dnsmasq

	setup_static_leases

	install_lease_api

	install_nat

	setup_port_forwards

	log 'Installation complete!'

	systemctl disable install-l2gateway
	rm -f /usr/lib/systemd/system/install-l2gateway.service

	poweroff
}

main
