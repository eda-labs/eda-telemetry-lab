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

## Common Requirements

1. **Kubernetes with EDA installed:** Check your EDA installation mode matches your deployment choice
2. **Helm:** Install from <https://helm.sh/docs/intro/install/>
3. **kubectl:** Verify installation with:

    ```bash
    kubectl -n eda-system get engineconfig engine-config \
    -o jsonpath='{.status.run-status}{"\n"}'
    ```

    Expected output: `Started`

## Step 1: Initialize the Lab

The `init.sh` script requires a user to provide the EDA URL and the rest happens automatically:

- Installs required tools (`uv`, `clab-connector`)
- Deploys the telemetry stack via Helm
- Configures syslog integration
- Saves EDA API address

```bash
EDA_URL=https://test.eda.com:9443 ./init.sh
```

## Step 2: Deploy Containerlab Topology

```bash
containerlab deploy -t eda-st.clab.yaml
```


## Step 3: Integrate Containerlab with EDA

```bash
clab-connector integrate \
  --topology-data clab-eda-st/topology-data.json \
  --eda-url "https://$(cat .eda_api_address)" \
  --skip-edge-intfs \
  --namespace eda-telemetry
```

> [!IMPORTANT]
> The `--skip-edge-intfs` flag is mandatory as LAG interfaces are created via manifests.

### Verify Deployment

After completing the deployment:

1. **Access Grafana:** Navigate to the Grafana UI using the URL provided in the script output
2. **Check EDA UI:** Verify all nodes and apps are operational
3. **Test connectivity:** SSH to nodes using their prefixes:
   - Containerlab: `ssh admin@clab-eda-st-leaf1`

## Accessing Network Elements

### SR Linux Nodes

Access via SSH using the appropriate prefix for your deployment:

| Deployment | Node Access Example | Management Network |
|------------|-------------------|-------------------|
| Containerlab | `ssh admin@clab-eda-st-leaf1` | 10.58.2.0/24 |

### Linux Clients

- **SSH Access:** `ssh admin@clab-eda-st-server1` (password: `multit00l`)
- **WebUI:** <http://localhost:8080> (exposed from server1)
  - Use the WebUI to simulate network failures by shutting down interfaces

> [!TIP]
> The WebUI on port 8080 allows you to interactively shutdown SR Linux interfaces to test network resilience and observe telemetry changes in real-time.

## Traffic Generation & Control

The `./clab/traffic.sh` script orchestrates bidirectional iperf3 tests between server containers to generate realistic network traffic for telemetry observation.

| Parameter | Default Value | Environment Variable |
|-----------|--------------|---------------------|
| Duration | 10000 seconds | `DURATION` |
| Bandwidth | 120K | - |
| Parallel Streams | 10 | - |
| MSS | 1400 | - |
| Report Interval | 1 second | - |

### Usage Examples

```bash
# Start all traffic flows
./clab/traffic.sh start all

# Start specific server traffic
./clab/traffic.sh start server3
./clab/traffic.sh start server4

# Stop all traffic
./clab/traffic.sh stop all

# Custom duration (60 seconds)
DURATION=60 ./clab/traffic.sh start all
```

> [!TIP]
> Monitor traffic impact in real-time through Grafana dashboards while tests are running.
