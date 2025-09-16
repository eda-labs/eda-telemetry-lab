#!/bin/bash

function install-uv {
    # error if uv is not in the path
    if ! command -v uv &> /dev/null;
    then
        echo "Installing uv";
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

}

# Check if EDA CX deployment is present
echo "Checking for EDA CX variant..."
CX_DEP=$(kubectl get -A deployment -l eda.nokia.com/app=cx 2>/dev/null | grep eda-cx || true)

if [[ -n "$CX_DEP" ]]; then
    echo "EDA CX variant detected."
    IS_CX=true
    NODE_PREFIX="eda-st"
else
    echo "Containerlab variant detected (no CX pods found)."
    IS_CX=false
    NODE_PREFIX="clab-eda-st"

    # install uv and clab-connector
    install-uv
    uv tool install git+https://github.com/eda-labs/clab-connector.git
    uv tool upgrade clab-connector
fi

# Update Grafana dashboard with correct node prefix
DASHBOARD_FILE="charts/telemetry-stack/files/grafana/dashboards/st.json"
if [[ -f "$DASHBOARD_FILE" ]]; then
    echo "Updating Grafana dashboard with node prefix: $NODE_PREFIX"
    # First replace clab-eda-st with a temporary marker, then replace eda-st, then replace marker with final prefix
    sed -i.bak "s/clab-eda-st/__TEMP_MARKER__/g" "$DASHBOARD_FILE"
    sed -i "s/eda-st/$NODE_PREFIX/g" "$DASHBOARD_FILE"
    sed -i "s/__TEMP_MARKER__/$NODE_PREFIX/g" "$DASHBOARD_FILE"
fi

# Install helm chart
echo "Installing telemetry-stack helm chart..."

proxy_var="${https_proxy:-$HTTPS_PROXY}"
if [[ -n "$proxy_var" ]]; then
    echo "Using proxy for grafana deployment: $proxy_var"
    noproxy="localhost\,127.0.0.1\,.local\,.internal\,.svc"

    helm install telemetry-stack ./charts/telemetry-stack \
    --set https_proxy="$proxy_var" \
    --set no_proxy="$noproxy" \
    --create-namespace -n eda-telemetry
else
    helm install telemetry-stack ./charts/telemetry-stack \
    --create-namespace -n eda-telemetry
fi



# Wait for alloy service to be ready and get external IP
echo "Waiting for alloy service to get external IP..."
echo "Note: First-time deployment may take several minutes while downloading container images."
ALLOY_IP=""
RETRY_COUNT=0
MAX_RETRIES=60  # Increased from 30 to 60 for initial deployments

# First, wait for the alloy pod to be ready
echo "Checking alloy pod status..."
kubectl wait --for=condition=ready pod -l app=alloy -n eda-telemetry --timeout=600s

# Now wait for the service to get an external IP
while [ -z "$ALLOY_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    ALLOY_IP=$(kubectl get svc alloy -n eda-telemetry -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$ALLOY_IP" ]; then
        echo "Waiting for external IP... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ -z "$ALLOY_IP" ]; then
    echo "Error: Failed to get alloy external IP after $MAX_RETRIES attempts"
    exit 1
fi

echo "Got alloy external IP: $ALLOY_IP"

# Update syslog.yaml with alloy IP
SYSLOG_CONFIG_FILE="manifests/0026_syslog.yaml"
CX_SYSLOG_CONFIG_FILE="cx/manifests/0026_syslog.yaml"

if [[ ! -f "$SYSLOG_CONFIG_FILE" ]]; then
    echo "Error: $SYSLOG_CONFIG_FILE not found."
    exit 1
fi

# Replace the IP in the host field for main syslog config
sed -i.bak -E "s/(\"host\": \")[^\"]+(\",)/\1${ALLOY_IP}\2/" "$SYSLOG_CONFIG_FILE"
echo "Updated syslog host to '$ALLOY_IP' in $SYSLOG_CONFIG_FILE"

# Also update CX syslog config if it exists
if [[ -f "$CX_SYSLOG_CONFIG_FILE" ]]; then
    sed -i.bak -E "s/(\"host\": \")[^\"]+(\",)/\1${ALLOY_IP}\2/" "$CX_SYSLOG_CONFIG_FILE"
    echo "Updated syslog host to '$ALLOY_IP' in $CX_SYSLOG_CONFIG_FILE"
fi

# Fetch EDA ext domain name from engine config
EDA_API=$(uv run ./scripts/get_eda_api.py)

# Ensure input is not empty
if [[ -z "$EDA_API" ]]; then
  echo "No input provided. Exiting."
  exit 1
fi

# save EDA API address to a file
echo "$EDA_API" > .eda_api_address

# Start port-forward for Grafana
echo "Starting Grafana port-forward on port 3000..."
echo ""
echo "Run the following command to access Grafana:"
echo "kubectl port-forward -n eda-telemetry service/grafana 3000:3000 --address=0.0.0.0"
echo ""
echo "Or run this in the background:"
echo "nohup kubectl port-forward -n eda-telemetry service/grafana 3000:3000 --address=0.0.0.0 >/dev/null 2>&1 &"

# Run namespace bootstrap for CX variant if detected
if [[ "$IS_CX" == "true" ]]; then
    echo ""
    echo "Running namespace bootstrap for CX variant..."
    
    # Define edactl alias function
    edactl() {
        kubectl -n eda-system exec -it $(kubectl -n eda-system get pods \
            -l eda.nokia.com/app=eda-toolbox -o jsonpath="{.items[0].metadata.name}") \
            -- edactl "$@"
    }
    
    # Run namespace bootstrap
    edactl namespace bootstrap eda-st
    
    if [ $? -eq 0 ]; then
        echo "Namespace bootstrap completed successfully."
    else
        echo "Warning: Namespace bootstrap failed. You may need to run it manually."
    fi
else
    echo ""
    echo "Containerlab variant - skipping namespace bootstrap."
fi