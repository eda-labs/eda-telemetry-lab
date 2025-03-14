#!/bin/bash
# A script for launching bidirectional traffic tests.
# This script assumes that:
#   • iperf3 servers on server1 and server2 are already running persistently.
#   • Docker container names are:
#         clab-eda-st-server1 (iperf server on server1)
#         clab-eda-st-server2 (iperf server on server2)
#         clab-eda-st-server3 (iperf client that will connect to server2)
#         clab-eda-st-server4 (iperf client that will connect to server1)
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
DURATION=${DURATION:-10000}    # Test duration in seconds
INTERVAL=1                     # Reporting interval (seconds)
PORT1=5201                     # Port for first set of tests (TCP/UDP)
PORT2=5202                     # Port for second set of tests (TCP/UDP)
PARALLEL=10                    # Number of parallel streams
BANDWIDTH="120K"               # Bandwidth parameter
MSS=1400                       # Maximum segment size
WINDOW=4K                      # Window size

# Define endpoints based on your design:
# Client4 will target server1's two interfaces:
SERVER4_CONTAINER="clab-eda-st-server4"
SERVER1_IP_TCP="10.10.10.1"   # Test over port 5201
SERVER1_IP_VLAN="10.20.1.1"   # Test over port 5202

# Client3 will target server2's two interfaces:
SERVER3_CONTAINER="clab-eda-st-server3"
SERVER2_IP_TCP="10.10.10.2"   # Test over port 5201
SERVER2_IP_VLAN="10.20.2.2"   # Test over port 5202

# Function to start tests from server4 toward server1
start_server4() {
    echo "Starting iperf3 traffic from server4 (${SERVER4_CONTAINER}) to server1..."
    # Launch two instances per endpoint for increased parallelism
    for i in {1..2}; do
        echo "  - Starting test: ${SERVER4_CONTAINER} -> ${SERVER1_IP_TCP}:${PORT1}"
        docker exec "${SERVER4_CONTAINER}" \
            iperf3 -c "${SERVER1_IP_TCP}" -t "${DURATION}" -i "${INTERVAL}" -p "${PORT1}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &

        echo "  - Starting test: ${SERVER4_CONTAINER} -> ${SERVER1_IP_VLAN}:${PORT2}"
        docker exec "${SERVER4_CONTAINER}" \
            iperf3 -c "${SERVER1_IP_VLAN}" -t "${DURATION}" -i "${INTERVAL}" -p "${PORT2}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &
    done
}

# Function to start tests from server3 toward server2
start_server3() {
    echo "Starting iperf3 traffic from server3 (${SERVER3_CONTAINER}) to server2..."
    for i in {1..2}; do
        echo "  - Starting test: ${SERVER3_CONTAINER} -> ${SERVER2_IP_TCP}:${PORT1}"
        docker exec "${SERVER3_CONTAINER}" \
            iperf3 -c "${SERVER2_IP_TCP}" -t "${DURATION}" -i "${INTERVAL}" -p "${PORT1}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &

        echo "  - Starting test: ${SERVER3_CONTAINER} -> ${SERVER2_IP_VLAN}:${PORT2}"
        docker exec "${SERVER3_CONTAINER}" \
            iperf3 -c "${SERVER2_IP_VLAN}" -t "${DURATION}" -i "${INTERVAL}" -p "${PORT2}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &
    done
}

# Function to stop iperf3 tests on a given container using pkill
stop_client() {
    local container="$1"
    echo "Stopping iperf3 traffic on ${container}..."
    docker exec "${container}" pkill iperf3 >/dev/null 2>&1 || true
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
                stop_client "${SERVER3_CONTAINER}"
                ;;
            server4)
                stop_client "${SERVER4_CONTAINER}"
                ;;
            all)
                stop_client "${SERVER3_CONTAINER}"
                stop_client "${SERVER4_CONTAINER}"
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
