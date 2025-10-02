#!/bin/bash

# Render control panel web UI when running in containerlab
TEMPLATE="/configs/webui/index.tmpl.html"
TARGET="/usr/share/nginx/html/index.html"
if [ -f "$TEMPLATE" ]; then
  mkdir -p "$(dirname "$TARGET")"
  sed -e "s/__leaf1_addr__/10.58.2.11/g" \
      -e "s/__leaf2_addr__/10.58.2.12/g" \
      -e "s/__leaf3_addr__/10.58.2.13/g" \
      -e "s/__leaf4_addr__/10.58.2.14/g" \
      -e "s/__spine1_addr__/10.58.2.21/g" \
      -e "s/__spine2_addr__/10.58.2.22/g" \
      "$TEMPLATE" > "$TARGET"
fi

ip link add bond0 type bond mode 802.3ad xmit_hash_policy layer3+4
ip link set addr 00:c1:ab:01:01:01 dev bond0
ip link set eth1 down
ip link set eth2 down
ip link set eth1 master bond0
ip link set eth2 master bond0
ip link set eth1 up
ip link set eth2 up
ip link set bond0 up
ip link add link bond0 name bond0.1001 type vlan id 1001
ip link add link bond0 name bond0.201 type vlan id 201
ip link set bond0.1001 up
ip link set bond0.201 up
ip addr add 10.10.10.1/24 dev bond0.1001
ip addr add 10.20.1.1/24 dev bond0.201
iperf3 -s -p 5201 -D
iperf3 -s -p 5202 -D
