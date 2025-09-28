#!/bin/bash

# Wait up to 120 seconds for eth1 and eth2 interfaces to exist
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if ip link show eth1 > /dev/null 2>&1 && ip link show eth2 > /dev/null 2>&1; then
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
    echo "Error: eth1 or eth2 interfaces did not appear within 120 seconds"
    exit 1
fi