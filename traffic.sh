#!/bin/bash
# A script for launching bidirectional traffic tests.
# This script assumes that:
#   • iperf3 servers on client1 and client2 are already running persistently.
#   • Docker container names are:
#         clab-eda-st-client1 (iperf server on client1)
#         clab-eda-st-client2 (iperf server on client2)
#         clab-eda-st-client3 (iperf client that will connect to client2)
#         clab-eda-st-client4 (iperf client that will connect to client1)
#
# The following test pairs are configured:
#   • client4 (10.10.10.4)  -> client1 (10.10.10.1)  on port 5201
#   • client4 (10.20.2.4)   -> client1 (10.20.1.1)   on port 5202
#   • client3 (10.10.10.3)  -> client2 (10.10.10.2)  on port 5201
#   • client3 (10.20.1.3)   -> client2 (10.20.2.2)   on port 5202
#
# Each test is run in bidirectional mode with the following defaults:
#   • Duration: 10000 seconds (modifiable via the DURATION environment variable)
#   • Report interval: 1 second
#   • Parallel streams: 10
#   • Bandwidth: 150K
#   • MSS: 1400
#
# Usage: ./traffic.sh {start|stop} {client3|client4|all}
#

set -euo pipefail

# Configuration defaults (override by exporting variables if needed)
DURATION=${DURATION:-10000}    # Test duration in seconds
INTERVAL=1                     # Reporting interval (seconds)
PORT1=5201                     # Port for first set of tests (TCP/UDP)
PORT2=5202                     # Port for second set of tests (TCP/UDP)
PARALLEL=10                    # Number of parallel streams
BANDWIDTH="150K"               # Bandwidth parameter
MSS=1400                       # Maximum segment size
WINDOW=4K                      # Window size

# Define endpoints based on your design:
# Client4 will target client1's two interfaces:
CLIENT4_CONTAINER="clab-eda-st-client4"
CLIENT1_IP_TCP="10.10.10.1"   # Test over port 5201
CLIENT1_IP_VLAN="10.20.1.1"   # Test over port 5202

# Client3 will target client2's two interfaces:
CLIENT3_CONTAINER="clab-eda-st-client3"
CLIENT2_IP_TCP="10.10.10.2"   # Test over port 5201
CLIENT2_IP_VLAN="10.20.2.2"   # Test over port 5202

# Function to start tests from client4 toward client1
start_client4() {
    echo "Starting iperf3 traffic from client4 (${CLIENT4_CONTAINER}) to client1..."
    # Launch two instances per endpoint for increased parallelism
    for i in {1..2}; do
        echo "  - Starting test: ${CLIENT4_CONTAINER} -> ${CLIENT1_IP_TCP}:${PORT1}"
        sudo docker exec "${CLIENT4_CONTAINER}" \
            iperf3 -c "${CLIENT1_IP_TCP}" --bidir -t "${DURATION}" -i "${INTERVAL}" -p "${PORT1}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &

        echo "  - Starting test: ${CLIENT4_CONTAINER} -> ${CLIENT1_IP_VLAN}:${PORT2}"
        sudo docker exec "${CLIENT4_CONTAINER}" \
            iperf3 -c "${CLIENT1_IP_VLAN}" --bidir -t "${DURATION}" -i "${INTERVAL}" -p "${PORT2}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &
    done
}

# Function to start tests from client3 toward client2
start_client3() {
    echo "Starting iperf3 traffic from client3 (${CLIENT3_CONTAINER}) to client2..."
    for i in {1..2}; do
        echo "  - Starting test: ${CLIENT3_CONTAINER} -> ${CLIENT2_IP_TCP}:${PORT1}"
        sudo docker exec "${CLIENT3_CONTAINER}" \
            iperf3 -c "${CLIENT2_IP_TCP}" --bidir -t "${DURATION}" -i "${INTERVAL}" -p "${PORT1}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &

        echo "  - Starting test: ${CLIENT3_CONTAINER} -> ${CLIENT2_IP_VLAN}:${PORT2}"
        sudo docker exec "${CLIENT3_CONTAINER}" \
            iperf3 -c "${CLIENT2_IP_VLAN}" --bidir -t "${DURATION}" -i "${INTERVAL}" -p "${PORT2}" \
                -P "${PARALLEL}" -w ${WINDOW} -b "${BANDWIDTH}" -M "${MSS}" >/dev/null 2>&1 &
    done
}

# Function to stop iperf3 tests on a given container using pkill
stop_client() {
    local container="$1"
    echo "Stopping iperf3 traffic on ${container}..."
    sudo docker exec "${container}" pkill iperf3 >/dev/null 2>&1 || true
}

usage() {
    echo "Usage: $0 {start|stop} {client3|client4|all}"
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
            client3)
                start_client3
                ;;
            client4)
                start_client4
                ;;
            all)
                start_client3
                start_client4
                ;;
            *)
                usage
                ;;
        esac
        ;;
    stop)
        case "$TARGET" in
            client3)
                stop_client "${CLIENT3_CONTAINER}"
                ;;
            client4)
                stop_client "${CLIENT4_CONTAINER}"
                ;;
            all)
                stop_client "${CLIENT3_CONTAINER}"
                stop_client "${CLIENT4_CONTAINER}"
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
