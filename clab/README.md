# 📦 Option A: Containerlab Deployment

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
