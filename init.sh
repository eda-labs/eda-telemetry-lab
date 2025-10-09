#!/bin/bash

function check-required-binaries {
    local missing_binaries=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_binaries+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_binaries+=("helm")
    fi
    
    if [ ${#missing_binaries[@]} -gt 0 ]; then
        echo "Error: Required binaries not found: ${missing_binaries[*]}"
        echo "Please install the missing binaries before running this script."
        echo "  https://github.com/eda-labs/eda-telemetry-lab?tab=readme-ov-file#requirements"
        exit 1
    fi
}

function install-uv {
    # error if uv is not in the path
    if ! command -v uv &> /dev/null;
    then
        echo "Installing uv";
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

}

indent_out() { sed 's/^/    /'; }

# Check required binaries before proceeding
check-required-binaries

# Term colors
GREEN="\033[0;32m"
RESET="\033[0m"

# k8s and cx namespace
# this is where the telemetry stack will be installed
# and in case of CX variant, where the nodes will be created
ST_STACK_NS=eda-telemetry

EDA_URL=${EDA_URL:-""} # e.g. https://my.eda.com or https://10.1.0.1:9443

# namespace where default EDA resources are
DEFAULT_USER_NS=eda

# Check if EDA CX deployment is present
CX_DEP=$(kubectl get -A deployment -l eda.nokia.com/app=cx 2>/dev/null | grep eda-cx || true)

if [[ -n "$CX_DEP" ]]; then
    echo -e "${GREEN}--> EDA CX variant detected.${RESET}"
    IS_CX=true
    NODE_PREFIX=${ST_STACK_NS}

    echo "Adding eda.nokia.com/bootstrap=true label to resources before bootstrapping the namespace" | indent_out

    kubectl -n ${DEFAULT_USER_NS} label nodeprofile srlinux-ghcr-25.7.2 eda.nokia.com/bootstrap=true | indent_out

    echo -e "${GREEN}--> Running namespace bootstrap for CX variant...${RESET}"
    
    # Define edactl alias function
    edactl() {
        kubectl -n eda-system exec $(kubectl -n eda-system get pods \
            -l eda.nokia.com/app=eda-toolbox -o jsonpath="{.items[0].metadata.name}") \
            -- edactl "$@"
    }

    # Run namespace bootstrap
    edactl namespace bootstrap ${ST_STACK_NS} | indent_out

    if [ $? -eq 0 ]; then
        echo "Namespace ${ST_STACK_NS} bootstrap completed successfully." | indent_out
    else
        echo "--> Warning: Namespace ${ST_STACK_NS} bootstrap failed. It may have been already bootstrapped, or you may need to run it manually."
    fi

    echo -e "${GREEN}--> Deploying topology in EDA Digital Twin (CX)${RESET}"
    bash ./cx/topology/topo.sh load cx/topology/topo.yaml cx/topology/simtopo.yaml 2>&1> /dev/null

    echo -e "${GREEN}--> Waiting for nodes to sync...${RESET}"
    kubectl -n ${ST_STACK_NS} wait --for=jsonpath='{.status.node-state}'=Synced toponode --all --timeout=300s | indent_out

    echo -e "${GREEN}--> Configuring servers in CX topology...${RESET}"
    bash ./cx/topology/configure-servers.sh | indent_out
else
    echo -e "${GREEN}Containerlab variant detected (no CX pods found).${RESET}"
    IS_CX=false
    NODE_PREFIX="clab-eda-st"

    # install uv and clab-connector
    install-uv
    uv tool install git+https://github.com/eda-labs/clab-connector.git
    uv tool upgrade clab-connector

        # Replace markers in the template and output to index.html
    sed -e "s/__leaf1_addr__/10.58.2.11/g" \
        -e "s/__leaf2_addr__/10.58.2.12/g" \
        -e "s/__leaf3_addr__/10.58.2.13/g" \
        -e "s/__leaf4_addr__/10.58.2.14/g" \
        -e "s/__spine1_addr__/10.58.2.21/g" \
        -e "s/__spine2_addr__/10.58.2.22/g" \
        ./configs/servers/webui/index.tmpl.html \
        > ./configs/servers/webui/index.html
fi

# Update Grafana dashboard with correct node prefix
DASHBOARD_FILE="charts/telemetry-stack/files/grafana/dashboards/st.json"
if [[ -f "$DASHBOARD_FILE" ]]; then
    echo -e "${GREEN}--> Updating Grafana dashboard with node prefix: $NODE_PREFIX${RESET}"
    # First replace clab-eda-st with a temporary marker, then replace eda-st, then replace marker with final prefix
    sed -i.bak "s/clab-eda-st/__TEMP_MARKER__/g" "$DASHBOARD_FILE"
    sed -i "s/eda-st/$NODE_PREFIX/g" "$DASHBOARD_FILE"
    sed -i "s/__TEMP_MARKER__/$NODE_PREFIX/g" "$DASHBOARD_FILE"
fi

# Install helm chart
echo -e "${GREEN}--> Installing telemetry-stack helm chart...${RESET}"

proxy_var="${https_proxy:-$HTTPS_PROXY}"
if [[ -n "$proxy_var" ]]; then
    echo "Using proxy for grafana deployment: $proxy_var"
    noproxy="localhost\,127.0.0.1\,.local\,.internal\,.svc"

    helm install telemetry-stack ./charts/telemetry-stack \
    --set https_proxy="$proxy_var" \
    --set no_proxy="$noproxy" \
    --set eda_url="${EDA_URL}" \
    --create-namespace -n ${ST_STACK_NS} | indent_out
else
    helm install telemetry-stack ./charts/telemetry-stack \
    --set eda_url="${EDA_URL}" \
    --create-namespace -n ${ST_STACK_NS} | indent_out
fi



echo -e "${GREEN}--> Waiting for alloy service be ready...${RESET}"
echo "Note: First-time deployment may take several minutes while downloading container images." | indent_out
ALLOY_IP=""
RETRY_COUNT=0
MAX_RETRIES=60  # Increased from 30 to 60 for initial deployments

# First, wait for the alloy pod to be ready
echo "Checking alloy pod status..." | indent_out
kubectl wait --for=condition=ready pod -l app=alloy -n ${ST_STACK_NS} --timeout=600s | indent_out

# Get external alloy IP when in Containerlab mode
if [[ "$IS_CX" != "true" ]]; then
    # Now wait for the service to get an external IP
    while [ -z "$ALLOY_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        ALLOY_IP=$(kubectl get svc alloy -n ${ST_STACK_NS} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
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

    echo "Got alloy IP: $ALLOY_IP"


    SYSLOG_CONFIG_FILE="manifests/common/0026_syslog.yaml"


    if [[ ! -f "$SYSLOG_CONFIG_FILE" ]]; then
        echo "Error: $SYSLOG_CONFIG_FILE not found."
        exit 1
    fi

    # Update syslog.yaml with alloy IP when in Containerlab mode
    # CX mode uses the internal DNS name
    sed -i.bak -E "s/(\"host\": \")[^\"]+(\",)/\1${ALLOY_IP}\2/" "$SYSLOG_CONFIG_FILE"
    echo "--> Updated syslog host to '$ALLOY_IP' in $SYSLOG_CONFIG_FILE"

    # Fetch EDA ext domain name from engine config
    EDA_API=$(uv run ./scripts/get_eda_api.py)

    # Ensure input is not empty
    if [[ -z "$EDA_API" ]]; then
    echo "No input provided. Exiting."
    exit 1
    fi

    # save EDA API address to a file
    echo "$EDA_API" > .eda_api_address

fi


# Install apps and EDA resources
echo -e "${GREEN}--> Installing EDA apps and creating EDA resources...${RESET}"
kubectl apply -f ./manifests/common | indent_out

# adding containerlab specific resources
if [[ "$IS_CX" != "true" ]]; then
    kubectl apply -f ./manifests/clab | indent_out
fi

# add control panel for cx
if [[ "$IS_CX" == "true" ]]; then
    kubectl create configmap control-panel-nginx-conf \
    --from-file=nginx.conf=configs/servers/webui/nginx.conf \
    -n ${ST_STACK_NS} --dry-run=client -o yaml | kubectl apply -f - | indent_out

    # Get addresses for each node
    leaf1_addr=$(kubectl get -n ${ST_STACK_NS} targetnode leaf1 -o jsonpath='{.spec.address}')
    leaf2_addr=$(kubectl get -n ${ST_STACK_NS} targetnode leaf2 -o jsonpath='{.spec.address}')
    leaf3_addr=$(kubectl get -n ${ST_STACK_NS} targetnode leaf3 -o jsonpath='{.spec.address}')
    leaf4_addr=$(kubectl get -n ${ST_STACK_NS} targetnode leaf4 -o jsonpath='{.spec.address}')
    spine1_addr=$(kubectl get -n ${ST_STACK_NS} targetnode spine1 -o jsonpath='{.spec.address}')
    spine2_addr=$(kubectl get -n ${ST_STACK_NS} targetnode spine2 -o jsonpath='{.spec.address}')

    # Replace markers in the template and output to index.html
    sed -e "s/__leaf1_addr__/$leaf1_addr/g" \
        -e "s/__leaf2_addr__/$leaf2_addr/g" \
        -e "s/__leaf3_addr__/$leaf3_addr/g" \
        -e "s/__leaf4_addr__/$leaf4_addr/g" \
        -e "s/__spine1_addr__/$spine1_addr/g" \
        -e "s/__spine2_addr__/$spine2_addr/g" \
        ./configs/servers/webui/index.tmpl.html \
        > ./configs/servers/webui/index.html

    kubectl create configmap control-panel-index-html \
    --from-file=index.html=./configs/servers/webui/index.html \
    -n ${ST_STACK_NS} --dry-run=client -o yaml | kubectl apply -f - | indent_out

    kubectl apply -f ./manifests/cx/controlpanel.yaml | indent_out
fi

echo -e "${GREEN}--> Waiting for Grafana deployment to be available...${RESET}"
kubectl -n ${ST_STACK_NS} wait --for=condition=available deployment/grafana --timeout=300s | indent_out

# Show connection details
echo ""
echo -e "${GREEN}--> Access Grafana: ${EDA_URL}/core/httpproxy/v1/grafana/d/Telemetry_Playground/${RESET}"
echo -e "${GREEN}--> Access Prometheus: ${EDA_URL}/core/httpproxy/v1/prometheus/query${RESET}"

if [[ "$IS_CX" == "true" ]]; then
    echo -e "${GREEN}--> Access Control Panel: ${EDA_URL}/core/httpproxy/v1/control-panel/${RESET}"
fi
