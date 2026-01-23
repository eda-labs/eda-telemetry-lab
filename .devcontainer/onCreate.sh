#!/bin/bash
source .devcontainer/utils.sh

dump_system_info

log "Waiting for docker"
T_START=$(date +%s)

ensure-docker-is-ready

T_END=$(date +%s)
log "Docker is ready. Took $((T_END-T_START)) seconds."

log "Creating k3d cluster"
T_START=$(date +%s)

# start the k3d cluster
k3d cluster create eda-demo \
    --image rancher/k3s:v1.34.1-k3s1 \
    --k3s-arg "--disable=traefik@server:*" \
    --volume "$HOME/.images.txt:/opt/images.txt@server:*" \
    --port "9443:443" \
    --port "9400-9410:9400-9410"

T_END=$(date +%s)
log "K3d cluster is ready. Took $((T_END-T_START)) seconds."

