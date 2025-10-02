#!/bin/bash

# Usage:
#   topo.sh load <path to topology yaml> <path to sim topology yaml> - copy the two yaml files to the toolbox then call api-server-topo with -f and -s options to load the two json files

# command/operation
CMD=${1}
# path to the topology yaml file (required for `load` command)
TOPO_YAML=${2}
# path to the edatopogen json file (required for `generate` command)
TOPOGEN_FILE=${2}
# path to the sim topo json file (required for `generate` command)
SIMTOPO_FILE=${3}
# namespace where the topology configmap is stored (default: eda)
TOPO_NS=${TOPO_NS:-eda-telemetry}
# namespace where the toolbox pod is running (default: eda-system)
CORE_NS=${CORE_NS:-eda-system}

if [[ "${CMD}" == "remove" ]]; then
  echo "Removing topology from namespace ${TOPO_NS}"
  cat <<EOF | kubectl apply -n ${TOPO_NS} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: eda-topology
data:
  eda.yaml: |
    {}
EOF

  echo "Removing sim topology from namespace ${TOPO_NS}"
  cat <<EOF | kubectl apply -n ${TOPO_NS} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: eda-topology-sim
data:
  sim.yaml: |
    {}
EOF

  kubectl -n ${CORE_NS} exec \
    $(kubectl get -n ${CORE_NS} pods \
    -l eda.nokia.com/app=eda-toolbox -o jsonpath="{.items[0].metadata.name}") \
    -- api-server-topo -n ${TOPO_NS}

fi

if [[ "${CMD}" == "load" ]]; then
  if [ -z "${TOPO_YAML}" ]; then
    echo "Error: Path to topology YAML file is required for 'load2'"
    exit 1
  fi
  if [ ! -f "${TOPO_YAML}" ]; then
    echo "Topology file ${TOPO_YAML} does not exist"
    exit 1
  fi

  if [ -z "${SIMTOPO_FILE}" ]; then
    echo "Error: Path to Sim topology YAML file is required for 'load2'"
    exit 1
  fi
  if [ ! -f "${SIMTOPO_FILE}" ]; then
    echo "Sim Topology file ${SIMTOPO_FILE} does not exist"
    exit 1
  fi

  # find toolbox pod
  TOOLBOX_POD=$(kubectl -n ${CORE_NS} get pods \
    -l eda.nokia.com/app=eda-toolbox -o jsonpath="{.items[0].metadata.name}")

  if [ -z "${TOOLBOX_POD}" ]; then
    echo "Could not find eda-toolbox pod in namespace ${CORE_NS}"
    exit 1
  fi

  # derive base topogen filename and copy into /tmp on the toolbox pod
  TOPO_FILENAME=$(basename -- "${TOPO_YAML}")
  SIMTOPO_FILENAME=$(basename -- "${SIMTOPO_FILE}")

  echo "Copying topology ${TOPO_YAML} to ${CORE_NS}/${TOOLBOX_POD}:/tmp/${TOPO_FILENAME}"
  kubectl -n ${CORE_NS} cp "${TOPO_YAML}" "${TOOLBOX_POD}:/tmp/${TOPO_FILENAME}" || {
    echo "kubectl cp failed"
    exit 1
  }

  echo "Copying sim topology ${SIMTOPO_FILE} to ${CORE_NS}/${TOOLBOX_POD}:/tmp/${SIMTOPO_FILENAME}"
  kubectl -n ${CORE_NS} cp "${SIMTOPO_FILE}" "${TOOLBOX_POD}:/tmp/${SIMTOPO_FILENAME}" || {
    echo "kubectl cp failed"
    exit 1
  }

  echo "Converting /tmp/${TOPO_FILENAME} to JSON format"
  kubectl -n ${CORE_NS} exec "${TOOLBOX_POD}" -- sh -c "yq -o json '.' /tmp/${TOPO_FILENAME} > /tmp/topo.json"
  echo "Converting /tmp/${SIMTOPO_FILENAME} to JSON format"
  kubectl -n ${CORE_NS} exec "${TOOLBOX_POD}" -- sh -c "yq -o json '.' /tmp/${SIMTOPO_FILENAME} > /tmp/simtopo.json"
  echo "Loading topology from /tmp/topo.json and /tmp/simtopo.json on the toolbox pod"
  kubectl -n ${CORE_NS} exec "${TOOLBOX_POD}" -- api-server-topo -n ${TOPO_NS} -f /tmp/topo.json -s /tmp/simtopo.json
  exit $?
fi