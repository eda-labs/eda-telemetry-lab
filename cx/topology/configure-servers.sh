#!/bin/bash

set -e


# namespace where the topology configmap is stored (default: eda)
TOPO_NS=${TOPO_NS:-eda-telemetry}
# namespace where the toolbox pod is running (default: eda-system)
CORE_NS=${CORE_NS:-eda-system}

echo "waiting for simlinks to be created"
kubectl -n ${TOPO_NS} wait --for=create simlink leaf1-ethernet-1-1 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink leaf1-ethernet-1-2 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink leaf3-ethernet-1-1 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink leaf3-ethernet-1-2 --timeout=120s

echo "enabling eth1/eth2 interfaces on servers"
# get deployment pod name and run the exec in one command
# do a loop with server1 server2 server3 server4

for server in server1 server2 server3 server4; do
  echo "Configuring $server IP and interfaces..."
  kubectl -n ${CORE_NS} exec -it \
      $(kubectl get -n ${CORE_NS} pods \
      -l eda.nokia.com/app=sim-${server} -o jsonpath="{.items[0].metadata.name}") \
      -- bash -c "$(cat configs/servers/$server.sh)"
done
