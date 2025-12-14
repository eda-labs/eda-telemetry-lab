#!/bin/bash

set -e


# namespace where the topology configmap is stored (default: eda)
TOPO_NS=${TOPO_NS:-eda-telemetry}
# namespace where the toolbox pod is running (default: eda-system)
CORE_NS=${CORE_NS:-eda-system}

echo "Waiting for simlinks to be created"
kubectl -n ${TOPO_NS} wait --for=create simlink l1-l2-e1-1-lag-1 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink l1-l2-e1-2-lag-2 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink l3-l4-e1-1-lag-1 --timeout=120s
kubectl -n ${TOPO_NS} wait --for=create simlink l3-l4-e1-2-lag-2 --timeout=120s

echo "Waiting for server pods to be ready..."
for server in server1 server2 server3 server4; do
  echo "Waiting for $server pod..."
  kubectl -n ${CORE_NS} wait --for=condition=ready pod -l eda.nokia.com/app=sim-${server} --timeout=300s
done

for server in server1 server2 server3 server4; do
  echo "Waiting for $server eth1/eth2 interfaces to appear..."
  kubectl -n ${CORE_NS} exec -it -c ${server} \
      $(kubectl get -n ${CORE_NS} pods \
      -l eda.nokia.com/app=sim-${server} -o jsonpath="{.items[0].metadata.name}") \
      -- bash -c "$(cat configs/servers/wait-for-ifaces.sh)"
done

echo "enabling eth1/eth2 interfaces on servers"
# get deployment pod name and run the exec in one command
# do a loop with server1 server2 server3 server4

for server in server1 server2 server3 server4; do
  echo "Configuring $server IP and interfaces..."
  kubectl -n ${CORE_NS} exec -it -c ${server} \
      $(kubectl get -n ${CORE_NS} pods \
      -l eda.nokia.com/app=sim-${server} -o jsonpath="{.items[0].metadata.name}") \
      -- bash -c "$(cat configs/servers/$server.sh)"
done
