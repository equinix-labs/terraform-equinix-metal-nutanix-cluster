
# Manual Installation

## Step 1: Deploy L2 Gateway

Assuming we don't have another gateway deployed, we'll need to create one.

<!-- TODO: migrate this script to live in the TF repo -->
We'll be using the helper scripts developed for running the test suite for Nutanix to simplify this installation.

```sh
#!/bin/bash

export EMAPI_AUTH_TOKEN=<your-metal-auth-token-here>
export L2GATEWAY_VLAN_DESCRIPTION=ntnx-demo

curl https://artifacts.platformequinix.com/images/nutanix/misc/scripts/install-l2gateway.sh | sh 2>&1 | tee /root/install-l2gw.log
```

## Step 2: Deploy one or more Nutanix Nodes (m3.xlarge)

## Step 3: Once installation is complete, move nodes to L2 mode

## Step 4: Reboot Nutanix nodes (to allow them to re-dhcp from new l2 gateway)

## Step 5: Discover CVM IPs

Look at the lease table on the dhcp server, and find all the kvm mac leases.

```sh
curl -s http://192.168.0.1/leases
```

## Step 5: Login to Nutanix CVM node and create cluster

```sh
ssh nutanix@$CVM_IP
cluster -s "CVM_IP1,CVM_IP2,CVM_IP3" create
```

## Step 6: Access Prism's UI

Open `https://$CVM_IP:9440` in your browser

Default login is `admin` and `nutanix/4u`

A password change will be required, we'll use `Nutanix.123`

Follow the account steps.

### Spawning a VM

#### Step 1: Configure DNS

Settings -> Name Servers
Add
8.8.8.8

#### Step 2: Add image

Settings -> Image Configuration
Upload Image

Name: Rocky8
Type: ISO
URL: <https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.5-x86_64-minimal.iso>

#### Step 3: Configure a network

Settings -> Network Configuration

Create Network

Network Name: vlan0
VLAN ID: 0

#### Step 4: Create VM

Settings -> VM

Create VM

Name: rocky8
vCPU(s): 8
Memory: 8

Disks
CDROM: Edit, use rocky8
Add New Disk:
  Size: 100

Save

Power on
