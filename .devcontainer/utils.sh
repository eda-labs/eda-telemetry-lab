#!/bin/bash

function ensure-docker-is-ready {
    echo "Ensuring docker daemon is available"
    until docker info > /dev/null 2>&1; do
        sleep 1
    done
    echo "Docker is ready"
}

function log {
    local msg="${1:-}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg"
}

function check_eda_api_reachability {
    log "Checking EDA API reachability"
    curl -vkf --retry 3 "https://127.0.0.1:$EDA_PORT" -o /dev/null
}

function dump_system_info {
    log "SYSTEM INFO: nproc"
    echo "System has $(nproc) CPUs"

    log "MEMORY: free -m"
    free -m

    log "DISK: df -h"
    df -h

    log "DISK: lsblk"
    lsblk
}