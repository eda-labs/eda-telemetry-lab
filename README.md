# Nokia EDA Telemetry Lab

[![Discord][discord-svg]][discord-url]

[discord-svg]: https://gitlab.com/rdodin/pics/-/wikis/uploads/b822984bc95d77ba92d50109c66c7afe/join-discord-btn.svg
[discord-url]: https://eda.dev/discord

The great divide between the tools network engineers use for configuration and those used for telemetry and monitoring leaves a significant gap in operational efficiency. As engineers build abstractions to configure the network and deploy the services on top of it, they also need to ensure that they can monitor the health of these services, and not just individual node-scoped metrics.

[**Nokia EDA (Event Driven Automation)**](https://docs.eda.dev/) platform enables its users not only solve the challenge of configuring the infrastructure services, but also to get real-time state associated with them.

In this lab, a leaf and spine network composed of six [Nokia SR Linux](https://learn.srlinux.dev/) data center switches is managed by EDA and integrated into a modern telemetry and logging stack powered by Prometheus, Grafana, Loki, Alloy and Kafka open-source projects.

![pic](https://gitlab.com/-/project/7617705/uploads/fe986438695fb7116fe26807a8509a64/CleanShot_2025-09-30_at_18.06.40.png)

The _all-in-one_ lab features the Grafana dashboard that takes the central stage of this lab, providing real-time insights into the health of the fabric and the network services, as well as serving as a single pane of glass for log aggregation and alarm monitoring:

<https://github.com/user-attachments/assets/38efb03a-c4aa-4a52-820a-b96d8a7005ea>

## Lab Components

- **Kubernetes platform:** The platform to run Nokia EDA. In this lab also hosts the telemetry stack components. Deployed automatically with [Kind](https://kind.sigs.k8s.io/) in a local lab environment.
  - **Nokia EDA:** Automation platform managing the network fabric and exporting telemetry data, logs and alarms to the downstream systems.
    - **Digital Twin (CX):** Horizontally scalable network simulation platform powered by Kubernetes, included with EDA.  
            A leaf-spine topology is created directly in EDA CX and features Nokia SR Linux nodes that have 100% YANG coverage and support gNMI streaming telemetry for all its paths.  
            Servers are represented with Linux containers equipped with `iperf3` to generate traffic and see dynamic network metrics in action.
  - **Kafka Exporter:** EDA application that can export various data from EDA to Kafka brokers. In this lab, it is used to export alarms and deviations.
  - **Prometheus Exporter:** EDA application that exports telemetry data in Prometheus format. In this lab, it is used to export fabric and services metrics, along with node-specific metrics.
  - **Telemetry & Logging Stack:**
    - **Prometheus:** Collects and stores telemetry data exported by EDA Prometheus exporter.
    - **Kafka:** Message broker that receives alarms and deviations from EDA via its Kafka exporter.
    - **Alloy:** Stream processing engine that analyzes, parses, transforms and enriches telemetry data received from network nodes (syslog) and Kafka exporter (alarms). Alloy then forwards the processed data to Loki for storage.
    - **Loki:** Log aggregation system that stores logs and alarms processed by Alloy.
    - **Grafana:** Visualization platform that provides dashboards for telemetry metrics, logs and alarms.

## Requirements

> [!IMPORTANT]
> **Nokia EDA Version:** 25.8.2 or later required. Free and automated [installation available](https://docs.eda.dev/25.8/getting-started/try-eda/).  
> The EDA platform must be installed and operational before proceeding with the lab deployment.

1. **Helm**  
    Kubernetes package manager. [Copy](https://docs.eda.dev/25.8/user-guide/using-the-clis/#helm) from your EDA playground directory or [install](https://helm.sh/docs/intro/install/).
2. **Kubectl**  
    Kubernetes CLI. [Copy](https://docs.eda.dev/25.8/user-guide/using-the-clis/#kubectl) from the playground directory or [install](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).

Before proceeding with the lab deployment, ensure you have a working EDA installation. You can use either:

```bash
kubectl -n eda-system get engineconfig engine-config \
-o jsonpath='{.status.run-status}{"\n"}'
```

Expected output: `Started`

## 🚀 Lab Deployment

The lab deployment is orchestrated by the `init.sh` script, which automates the setup by performing the following tasks:

- Creates the `eda-telemetry` namespace
- Deploys the fabric nodes
- Deploys and configures the telemetry and logging stack
- Configures the servers interfaces
- Configures EDA resources for exporting telemetry, logs and alarms

The user must provide the `EDA_URL` environment variable pointing to their EDA UI/API endpoint:

```bash
EDA_URL=https://test.eda.com:9443 ./init.sh
```

> [!NOTE]
> If you want to use Containerlab instead of EDA Digital Twin, refer to the [Containerlab deployment](./clab/README.md) instructions.

### Verify Deployment

When the deployment completes, you should see the URL to access Grafana dashboard:

> Navigate to the ${EDA_URL}/core/httpproxy/v1/grafana/d/Telemetry_Playground/ to access Grafana.

The dashboard should display the deployed topology, and all the panels should be populating with data.

You can also log in to EDA UI and see the `eda-telemetry` namespace in the list of namespaces and the associated resources created by the lab deployment script.

## Accessing Network Elements

To access the SR Linux nodes, use the provided node-ssh.sh script in the `./cx` directory of the lab:

```bash
./cx/node-ssh leaf1
```

> SR Linux default credentials: `admin` / `NokiaSrl1!`

To open up the shell to the server containers, use the provided container-shell script in the `./cx` directory of the lab:

```bash
./cx/container-shell server1
```

The shell is opened for the `admin` user.

## Telemetry & Logging Stack

### Telemetry

<p align="center">
  <img src="./docs/eda_telemetry_lab-tooling.drawio.svg" alt="Drawio Example">
</p>

Nokia EDA is the single interface for the telemetry data collection and export. As part of its normal operation, EDA collects telemetry data such as node-scoped metrics, service metrics, alarms and deviations. The data is then exported to the downstream systems using the following EDA applications:

- **Prometheus Exporter:** Using the `Export` resource the admin instructs the application what metrics to make available in a Prometheus format. See the [`0020_prom_exporters.yaml`](./cx/manifests/0020_prom_exporters.yaml) manifest for details.  
    The Prometheus server running in the k8s cluster is configured to scrape the metrics exported by the Prometheus exporter app.  
    The Prometheus UI can be accessed via:
    > `${EDA_URL}/core/httpproxy/v1/prometheus/query`
- **Kafka Exporter:** Using the `Producer` resource the admin instructs the application to send deviations and alarms to the Kafka broker running in the cluster. See the [`0021_kafka_exporter.yaml`](./cx/manifests/0021_kafka_exporter.yaml) manifest for details.  
    The Grafana Alloy application is configured to consume the alarms and deviations from Kafka, process them and forward them to Loki for storage.

### Logging

The Syslog messages are sent directly from the SR Linux nodes to Grafana Alloy, which processes and forwards them to Loki for storage.

## Services and Traffic Generation

To simulate a datacenter pod, the lab features four Linux containers acting as servers connected to the leaf switches.

Servers are configured with bond interfaces and a pair of VLANs simulating two different tenants in the datacenter. The tenants have their workloads connected using two distinct services:

- Layer 2 service using MAC VRF
- Layer 3 service using a combination of the MAC VRF and IP VRF

The following diagram illustrates the services and the participating VLANs:

![high-level-svc](https://gitlab.com/-/project/7617705/uploads/641816f3d1380ed2ebdacbee7f7d28c9/CleanShot_2025-10-01_at_15.35.43.png)

<details>
<summary><b>Detailed connectivity diagram</b></summary>
<a href="https://gitlab.com/-/project/7617705/uploads/1f1ccf12b0261b861ae6652d427b79ea/CleanShot_2025-10-01_at_15.36.18.png"><img src=https://gitlab.com/-/project/7617705/uploads/1f1ccf12b0261b861ae6652d427b79ea/CleanShot_2025-10-01_at_15.36.18.png/></a>
</details>

The `./cx/traffic.sh` script orchestrates bidirectional iperf3 tests between server containers to generate realistic network traffic for telemetry observation.

### Traffic Parameters

| Parameter | Default Value | Environment Variable |
|-----------|--------------|---------------------|
| Duration | 10000 seconds | `DURATION` |
| Bandwidth | 120K | - |
| Parallel Streams | 20 | - |
| MSS | 1400 | - |
| Report Interval | 1 second | - |

### Usage Examples

```bash
# Start all traffic flows
./cx/traffic.sh start all

# Start specific server traffic
./cx/traffic.sh start server3
./cx/traffic.sh start server4

# Stop all traffic
./cx/traffic.sh stop all

# Custom duration (60 seconds)
DURATION=60 ./cx/traffic.sh start all
```

> [!TIP]
> Monitor traffic impact in real-time through Grafana dashboards while tests are running.

## EDA Configuration

The lab is entirely automated, with all the necessary EDA resources declaratively defined in the manifests located in the `./manifests/common` directories. Here is a short summary of the manifests and their purposes:

| File | Description |
|------|-------------------------|
| `0000_apps.yaml` | Install EDA Prometheus and Kafka exporter apps |
| `0020_prom_exporters.yaml` | Configuring Prometheus exporters to expose metrics for Prometheus |
| `0021_kafka_exporter.yaml` | Configuring Kafka exporter for event streaming (alarms, deviations) |
| `0025_json-rpc.yaml` | Configlet to configure JSON-RPC server on SR Linux nodes |
| `0026_syslog.yaml` | Configlet to configure logging on SR Linux nodes |
| `0030_fabric.yaml` | Fabric resource to deploy EVPN fabric |
| `0040_ipvrf2001.yaml` | L3 Virtual Network to support L3 overlay services |
| `0041_macvrf1001.yaml` | L2 Virtual Network to support L2 overlay services |
| `0050_http_proxy.yaml` | HTTP proxy service to expose Grafana and Prometheus UI |

## Removing the lab

To remove the lab, remove the namespace it was deployed in using [edactl](https://docs.eda.dev/25.8/user-guide/using-the-clis/#edactl) and kubectl:

```bash
edactl delete namespace eda-telemetry && \
kubectl wait --for=delete namespace eda-telemetry --timeout=300s
```

After deleting the namespace, you can redeploy the lab by running the `init.sh` script again.

## Troubleshooting

<details>
<summary><b>Pods stuck in pending state</b></summary>

Check if images are still downloading:

```bash
kubectl get pods -n eda-telemetry -o wide
kubectl describe pod <pod-name> -n eda-telemetry
```

</details>

<details>
<summary><b>Alloy service no external IP</b></summary>

Verify MetalLB or load balancer configuration:

```bash
kubectl get svc -n eda-telemetry
kubectl logs -n metallb-system -l app=metallb
```

</details>

<details>
<summary><b>CX namespace bootstrap fails</b></summary>

Manually run the bootstrap:

```bash
kubectl -n eda-system exec -it $(kubectl -n eda-system get pods \
  -l eda.nokia.com/app=eda-toolbox -o jsonpath="{.items[0].metadata.name}") \
  -- edactl namespace bootstrap eda-st
```

</details>

<details>
<summary><b>Traffic script fails</b></summary>

Ensure containers are running (Containerlab only):

```bash
sudo docker ps | grep eda-st
containerlab inspect -t eda-st.clab.yaml
```

</details>

## Resources

- **Documentation:** [EDA Docs](https://docs.eda.dev/)
- **Support:** [EDA Discord Community](https://eda.dev/discord)
- **SR Linux Learn:** [SR Linux Learning Platform](https://learn.srlinux.dev/)
- **Containerlab:** [Containerlab Documentation](https://containerlab.dev/)

---

Happy automating and exploring your network with EDA Telemetry Lab! 🚀
