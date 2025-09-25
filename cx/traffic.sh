#!/bin/bash
# A script for launching bidirectional traffic tests.
# This script restarts iperf3 servers before starting clients to ensure clean connections.
# Kubernetes deployments in namespace eda-system:
#         cx-eda-telemetry--server1-sim (iperf server on server1)
#         cx-eda-telemetry--server2-sim (iperf server on server2)
#         cx-eda-telemetry--server3-sim (iperf client that will connect to server2)
#         cx-eda-telemetry--server4-sim (iperf client that will connect to server1)
#
# The following test pairs are configured:
#   • server4 (10.10.10.4)  -> server1 (10.10.10.1)  on port 5201
#   • server4 (10.20.2.4)   -> server1 (10.20.1.1)   on port 5202
#   • server3 (10.10.10.3)  -> server2 (10.10.10.2)  on port 5201
#   • server3 (10.20.1.3)   -> server2 (10.20.2.2)   on port 5202
#
# Each test is run in bidirectional mode with the following defaults:
#   • Duration: 10000 seconds (modifiable via the DURATION environment variable)
#   • Report interval: 1 second
#   • Parallel streams: 10
#   • Bandwidth: 120K
#   • MSS: 1400
#
# Usage: ./traffic.sh {start|stop} {server3|server4|all}
#

set -euo pipefail

# Configuration defaults (override by exporting variables if needed)
DURATION=${DURATION:-10000}       # Test duration in seconds
INTERVAL=1                        # Reporting interval (seconds)
PORT1=5201                        # Port for first set of tests (TCP/UDP)
PORT2=5202                        # Port for second set of tests (TCP/UDP)
PARALLEL=20                       # Number of parallel streams
BANDWIDTH="120K"                  # Bandwidth parameter
MSS=1400                          # Maximum segment size
WINDOW=4K                         # Window size
CORE_NS=${CORE_NS:-"eda-system"}  # Kubernetes namespace

# Define deployments
DEPLOYMENT_SERVER1="cx-eda-telemetry--server1-sim"
DEPLOYMENT_SERVER2="cx-eda-telemetry--server2-sim"
DEPLOYMENT_SERVER3="cx-eda-telemetry--server3-sim"
DEPLOYMENT_SERVER4="cx-eda-telemetry--server4-sim"

# Get pod names (assuming standard K8s labels)
SERVER1_POD=$(kubectl get -n ${CORE_NS} pods \
    -l eda.nokia.com/app=sim-server1 -o jsonpath="{.items[0].metadata.name}")
SERVER2_POD=$(kubectl get -n ${CORE_NS} pods \
    -l eda.nokia.com/app=sim-server2 -o jsonpath="{.items[0].metadata.name}")
SERVER3_POD=$(kubectl get -n ${CORE_NS} pods \
    -l eda.nokia.com/app=sim-server3 -o jsonpath="{.items[0].metadata.name}")
SERVER4_POD=$(kubectl get -n ${CORE_NS} pods \
    -l eda.nokia.com/app=sim-server4 -o jsonpath="{.items[0].metadata.name}")

# Define endpoints based on your design:
# Server pods
# Client4 will target server1's two interfaces:
SERVER1_IP_TCP="10.10.10.1"   # Test over port 5201
SERVER1_IP_VLAN="10.20.1.1"   # Test over port 5202

# Client3 will target server2's two interfaces:
SERVER2_IP_TCP="10.10.10.2"   # Test over port 5201
SERVER2_IP_VLAN="10.20.2.2"   # Test over port 5202

# Function to restart iperf3 servers to ensure clean connections
restart_iperf_servers() {
    echo "Restarting iperf3 servers to ensure clean connections..."

    # Kill existing iperf3 servers on server1 and server2
    kubectl exec $SERVER1_POD -n ${CORE_NS} -- pkill iperf3 >/dev/null 2>&1 || true
    kubectl exec $SERVER2_POD -n ${CORE_NS} -- pkill iperf3 >/dev/null 2>&1 || true

    sleep 2

    # Start new iperf3 servers on server1
    echo "  - Starting iperf3 servers on ${SERVER1_POD}"
    kubectl exec $SERVER1_POD -n ${CORE_NS} -- sh -c "iperf3 -s -p ${PORT1} > /dev/null 2>&1 &"
    kubectl exec $SERVER1_POD -n ${CORE_NS} -- sh -c "iperf3 -s -p ${PORT2} > /dev/null 2>&1 &"
    
    # Start new iperf3 servers on server2
    echo "  - Starting iperf3 servers on ${SERVER2_POD}"
    kubectl exec $SERVER2_POD -n ${CORE_NS} -- sh -c "iperf3 -s -p ${PORT1} > /dev/null 2>&1 &"
    kubectl exec $SERVER2_POD -n ${CORE_NS} -- sh -c "iperf3 -s -p ${PORT2} > /dev/null 2>&1 &"
    
    sleep 2
    echo "iperf3 servers restarted successfully"
}

# Function to start tests from server4 towards server1
start_server4() {
    echo "Starting iperf3 traffic from server4 (${SERVER4_POD}) to server1..."
    # Only one instance per endpoint (servers can only handle one connection at a time)
    echo "  - Starting test: ${SERVER4_POD} -> ${SERVER1_IP_TCP}:${PORT1}"
    kubectl exec $SERVER4_POD -n ${CORE_NS} -- sh -c "timeout $((DURATION + 10)) iperf3 -c '${SERVER1_IP_TCP}' -t '${DURATION}' -i '${INTERVAL}' -p '${PORT1}' -P '${PARALLEL}' -w ${WINDOW} -b '${BANDWIDTH}' -M '${MSS}' --connect-timeout 5000 > /dev/null 2>&1 &"

    echo "  - Starting test: ${SERVER4_POD} -> ${SERVER1_IP_VLAN}:${PORT2}"
    kubectl exec $SERVER4_POD -n ${CORE_NS} -- sh -c "timeout $((DURATION + 10)) iperf3 -c '${SERVER1_IP_VLAN}' -t '${DURATION}' -i '${INTERVAL}' -p '${PORT2}' -P '${PARALLEL}' -w ${WINDOW} -b '${BANDWIDTH}' -M '${MSS}' --connect-timeout 5000 > /dev/null 2>&1 &"
}

# Function to start tests from server3 towards server2
start_server3() {
    echo "Starting iperf3 traffic from server3 (${SERVER3_POD}) to server2..."
    # Only one instance per endpoint (servers can only handle one connection at a time)
    echo "  - Starting test: ${SERVER3_POD} -> ${SERVER2_IP_TCP}:${PORT1}"
    kubectl exec $SERVER3_POD -n ${CORE_NS} -- sh -c "timeout $((DURATION + 10)) iperf3 -c '${SERVER2_IP_TCP}' -t '${DURATION}' -i '${INTERVAL}' -p '${PORT1}' -P '${PARALLEL}' -w ${WINDOW} -b '${BANDWIDTH}' -M '${MSS}' --connect-timeout 5000 > /dev/null 2>&1 &"

    echo "  - Starting test: ${SERVER3_POD} -> ${SERVER2_IP_VLAN}:${PORT2}"
    kubectl exec $SERVER3_POD -n ${CORE_NS} -- sh -c "timeout $((DURATION + 10)) iperf3 -c '${SERVER2_IP_VLAN}' -t '${DURATION}' -i '${INTERVAL}' -p '${PORT2}' -P '${PARALLEL}' -w ${WINDOW} -b '${BANDWIDTH}' -M '${MSS}' --connect-timeout 5000 > /dev/null 2>&1 &"
}

# Function to stop iperf3 tests on a given pod using pkill
stop_client() {
    local pod="$1"
    echo "Stopping iperf3 traffic on ${pod}..."
    kubectl exec "$pod" -n ${CORE_NS} -- pkill iperf3 >/dev/null 2>&1 || true
}

usage() {
    echo "Usage: $0 {start|stop} {server3|server4|all}"
    exit 1
}

if [ "$#" -ne 2 ]; then
    usage
fi

ACTION="$1"
TARGET="$2"

case "$ACTION" in
    start)
        # Always restart iperf3 servers before starting clients
        restart_iperf_servers
        
        case "$TARGET" in
            server3)
                start_server3
                ;;
            server4)
                start_server4
                ;;
            all)
                start_server3
                start_server4
                ;;
            *)
                usage
                ;;
        esac
        ;;
    stop)
        case "$TARGET" in
            server3)
                stop_client "${SERVER3_POD}"
                ;;
            server4)
                stop_client "${SERVER4_POD}"
                ;;
            all)
                stop_client "${SERVER3_POD}"
                stop_client "${SERVER4_POD}"
                ;;
            *)
                usage
                ;;
        esac
        ;;
    *)
        usage
        ;;
esac

echo "Done."
