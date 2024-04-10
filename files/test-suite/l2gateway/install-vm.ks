auth --enableshadow --passalgo=sha512
url --url="https://download.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os"

rootpw --plaintext nutanix/4u
text
firewall --enabled --service=ssh
firstboot --disabled
eula --agreed
ignoredisk --only-use=vda
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
network  --bootproto=dhcp --device=link --activate --hostname=nutanix-gateway.localdomain
reboot
services --disabled="kdump" --enabled="sshd,rsyslog,chronyd"
skipx

timezone UTC --isUtc
bootloader --append="console=tty0 console=ttyS0,115200n8 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda
zerombr
clearpart --all --initlabel
part / --fstype="xfs" --ondisk=vda --size=1 --grow

%packages
@core
tar
wget
rsync
%end

%post
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        l2gateway-*)
            varname=${arg%%=*}
            varname=${varname//-/_}
            varname=${varname^^}
            newvar="${varname}=${arg#*=}"
            echo "$newvar" >> /etc/default/install-l2gateway
            export "$newvar"
            ;;
    esac
done

cat <<'EOF' | tee /bin/install-l2gateway.sh
#!/bin/sh
set -e

curl "$L2GATEWAY_INSTALL_SERVICE_URL" | sh
EOF

chmod +x /bin/install-l2gateway.sh

cat <<EOF | tee /usr/lib/systemd/system/install-l2gateway.service
[Unit]
Description=Install L2 Gateway.
After=network-online.target

[Service]
EnvironmentFile=/etc/default/install-l2gateway
ExecStart=/bin/install-l2gateway.sh
Restart=no

[Install]
WantedBy=multi-user.target
EOF

ln -nsf /usr/lib/systemd/system/install-l2gateway.service /etc/systemd/system/multi-user.target.wants/install-l2gateway.service
%end
