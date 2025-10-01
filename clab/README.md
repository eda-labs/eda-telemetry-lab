# 📦 Containerlab Deployment

- **EDA Mode:** `Simulate=False` - integrates with external Containerlab nodes
- **Architecture:** SR Linux nodes and client containers run via Containerlab, telemetry stack runs in Kubernetes
- **License:** Requires valid EDA hardware license (version 25.8+)
- **Traffic Generation:** ✅ Full iperf3 support for realistic network testing
- **Node Prefix:** `clab-eda-st-*` (e.g., `clab-eda-st-leaf1`)
- **Use Case:** Re-using EDA installations with Simulate=False mode.

> [!IMPORTANT]
> **EDA Version:** 25.8.2 or later required
>
> **For Containerlab:** EDA must be installed with `Simulate=False` mode ([see docs][sim-false-doc]) and a valid EDA license is required.
>
> <small>License is not required for CX-based deployment.</small>

[sim-false-doc]: https://docs.eda.dev/user-guide/containerlab-integration/#installing-eda

Requires EDA with `Simulate=False`.

## Step 1: Deploy Containerlab Topology

```bash
containerlab deploy -t eda-st.clab.yaml
```

## Step 2: Initialize the Lab

The `init.sh` script requires a user to provide the EDA URL and the rest happens automatically:

- Installs required tools (`uv`, `clab-connector`)
- Deploys the telemetry stack via Helm
- Configures syslog integration
- Saves EDA API address

```bash
EDA_URL=https://test.eda.com:9443 ./init.sh
```

## Step 3: Start Grafana Port-Forward

```bash
# Foreground (recommended for first-time setup)
kubectl port-forward -n eda-telemetry service/grafana 3000:3000 --address=0.0.0.0

# Or background
nohup kubectl port-forward -n eda-telemetry service/grafana 3000:3000 --address=0.0.0.0 >/dev/null 2>&1 &
```

## Step 4: Install EDA Apps

```bash
kubectl apply -f manifests/0000_apps.yaml
```

Wait for apps to be ready in the EDA UI (this may take a few minutes).

## Step 5: Integrate Containerlab with EDA

```bash
clab-connector integrate \
  --topology-data clab-eda-st/topology-data.json \
  --eda-url "https://$(cat .eda_api_address)" \
  --skip-edge-intfs
```

> [!IMPORTANT]
> The `--skip-edge-intfs` flag is mandatory as LAG interfaces are created via manifests.

## Step 6: Deploy Configuration Manifests

```bash
kubectl apply -f manifests
```

## Accessing Network Elements

### SR Linux Nodes

Access via SSH using the appropriate prefix for your deployment:

| Deployment | Node Access Example | Management Network |
|------------|-------------------|-------------------|
| Containerlab | `ssh admin@clab-eda-st-leaf1` | 10.58.2.0/24 |
| CX | `ssh admin@eda-st-leaf1` | Auto-assigned |

### Linux Clients (Containerlab only)

- **SSH Access:** `ssh admin@clab-eda-st-server1` (password: `multit00l`)
- **WebUI:** <http://localhost:8080> (exposed from server1)
  - Use the WebUI to simulate network failures by shutting down interfaces

> [!TIP]
> The WebUI on port 8080 allows you to interactively shutdown SR Linux interfaces to test network resilience and observe telemetry changes in real-time.
