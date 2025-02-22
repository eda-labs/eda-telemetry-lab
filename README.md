# EDA Telemetry Lab

[![Discord][discord-svg]][discord-url]

[discord-svg]: https://gitlab.com/rdodin/pics/-/wikis/uploads/b822984bc95d77ba92d50109c66c7afe/join-discord-btn.svg
[discord-url]: https://eda.dev/discord

The **EDA Telemetry Lab** demonstrates how to leverage full 100% YANG telemetry support integrated with [EDA (Event Driven Automation)](https://docs.eda.dev/). In this lab, [Nokia SR Linux](https://learn.srlinux.dev/) nodes are dynamically configured via EDA and integrated into a modern telemetry and logging stack that includes Prometheus, Grafana, Promtail, Loki, Alloy and Kafka exporters for alarms and deviations.

<p align="center">
  <img src="./docs/dashboard.png" alt="Drawio Example">
</p>

- **EDA-Driven Configuration:** Automate SR Linux configuration and telemetry subscriptions with EDA.
- **Modern Telemetry Stack:** Export telemetry data using EDA’s Prometheus exporter and monitor alarms/deviations via the Kafka exporter.
- **Enhanced Logging:** Capture and aggregate system logs using Promtail, Alloy and Loki.
- **Deployment Options:** Deploy with either Containerlab (clab) for live traffic or CX (Simulation Platform) for license-flexible testing.
- **Traffic:** Generate and control iperf3 traffic to see dynamic network metrics in action.

## Lab Components

- **Fabric:** A Clos topology of Nokia SR Linux nodes.
- **Telemetry:** SR Linux nodes stream full YANG telemetry data. EDA exports these metrics via its Prometheus exporter and sends alarms/deviations using its Kafka exporter.
- **Visualization:** Grafana dashboards (with the [Flow Plugin](https://grafana.com/grafana/plugins/andrewbmchugh-flow-panel/)) provide real-time insights into network metrics.
- **Alarms:** Data is collected by Kafka, processed by Alloy and aggregated in Loki, with logs viewable in Grafana.
- **Traffic Generation:** Use iperf3 tests and provided scripts to simulate live traffic across the network.

## Deployment Variants

There are two variants for deploying the lab.

### Variant 1: Containerlab
>
> [!IMPORTANT]
> **EDA Installation Mode:** This lab requires EDA to be installed in the [`Simulate=False`][sim-false-doc] mode. Ensure that your EDA deployment is configured accordingly.
>
> **Hardware License:** A valid `hardware license` for EDA version 24.12 is mandatory for using this lab.

[sim-false-doc]: https://docs.eda.dev/user-guide/containerlab-integration/#installing-eda

1. **Ensure `kubectl` is installed and configured:**
    To test if `kubectl` is installed and configured, run:

    ```
    kubectl -n eda-system get engineconfig engine-config \
    -o jsonpath='{.status.run-status}{"\n"}'
    ```

    You should see `Started` in the output.

2. **Initialize the Lab Configuration:**

    Run the provided `init.sh` which does the following:

    - ensures `uv` and `clab-connector` tools are installed
    - retrieves the EDA IP and sets it in the `configs/prometheus/prometheus.yml` files.
    - save EDA API address in a `.eda_api_address` file.

3. **Deploy containerlab topology:**

    Run `containerlab deploy -t eda-st.clab.yaml` to deploy the lab.

4. **Install the EDA Apps (Prometheus and Kafka):**

    Run:

    ```
    kubectl apply -f manifests/0000_apps.yaml
    ```

    **TIP:** Depending on your setup this can take couple of seconds/minutes. Please check in the EDA UI if the apps are installed.

5. **Integrate Containerlab with EDA:**

    Run:

    ```bash
    clab-connector integrate \
    --topology-data clab-eda-st/topology-data.json \
    --eda-url https://$(cat .eda_api_address)
    ```

    **TIP:** Check [Clab Connector](https://github.com/eda-labs/clab-connector) docs for more details on the clab-connector options.

6. **Deploy the Manifests:**

    Apply the manifests:

    ```
    kubectl apply -f manifests/clab
    ```

7. **Enjoy Your Lab!**

### Variant 2: CX (Simulation Platform)
>
> [!NOTE]
> Works without any license but its limited in traffic generation.

1. **Initialize the Lab Configuration:**

    Run the provided `init.sh` script to update your configuration files with the EDA IP address.

2. **Deploy containerlab topology:**

    Run `containerlab deploy -t eda-st-cx.clab.yaml` to deploy the lab.

3. **Bootstrap the Namespace in EDA:**

    Execute:

    ```
    kubectl exec -n eda-system $(kubectl get pods -n eda-system | grep eda-toolbox | awk '{print $1}') -- edactl namespace bootstrap clab-eda-st
    ```

4. **Install the EDA Apps (Prometheus and Kafka):**

    Run:

    ```
    kubectl apply -f manifests/with_cx/0000_apps.yaml
    ```

    **TIP:** Depending on your setup this can take a couple of seconds/minutes. Please check in the EDA UI if the apps are installed.

5. **Deploy the Lab:**

    Apply the manifests:

    ```
    kubectl apply -f manifests/with_cx
    ```

6. **Enjoy Your Lab!**

---

## Accessing Network Elements in clab

- **SR Linux Nodes:**
  Access these devices via SSH using the management IP addresses or hostnames (e.g., `ssh clab-eda-st-leaf2`).

- **Linux Clients:**
  Access client-emulating container via SSH: e.g. `ssh user@clab-eda-st-client3` (password: `multit00l`).

## Accessing Network Elements in cx (Simulation Platform)

- **SR Linux Nodes:**
  Access these devices via the SR Linux CLI using the following command:

    ```
    kubectl get pods -n eda-system | grep leaf1 | awk '{print "kubectl exec -it -n eda-system " $1 " -- sudo sr_cli"}'
    ```

> [!NOTE]
> Replace grep leaf1 with the desired node name.

---

## Telemetry & Logging Stack

### Telemetry

<p align="center">
  <img src="./docs/eda_telemetry_lab-tooling.drawio.svg" alt="Drawio Example">
</p>

- **SR Linux Telemetry:**
  Nodes stream full YANG telemetry data.
- **EDA Exporters:**
  - **Prometheus Exporter:** EDA exports detailed telemetry metrics to Prometheus.
  - **Kafka Exporter:** Alarms and deviations are forwarded via EDA’s Kafka exporter, enabling proactive monitoring and alerting.
- **Prometheus:**
  Stores the telemetry data. The configuration (located in `configs/prometheus/prometheus.yml`) is updated during initialization.
- **Grafana:**
  Visualize metrics and dashboards at <http://grafana:3000>. For admin tasks, use admin/admin.

### Logging

- **Alloy & Loki:**
  Alloy processes Kafka data and sends it to Loki for storage.
  Alloy has a web interface at <http://alloy:12345>.
- **Promtail & Loki:**
  Collect and aggregate SR Linux syslogs (e.g., BGP events, interface state changes). Logs are accessible and filterable via Grafana.
- **Prometheus UI:**
  Check out real-time graphs at <http://prometheus:9090/graph>.

## Traffic Generation & Control

The lab includes a traffic script (named **traffic.sh**) that launches bidirectional iperf3 tests between designated clients.

**Test Pairs Configured:**

- **Client4 to Client1:**
  - From client4 (`clab-eda-st-client4`) targeting client1’s IP `10.10.10.1` on port **5201**
  - From client4 targeting client1’s VLAN interface `10.20.1.1` on port **5202**

- **Client3 to Client2:**
  - From client3 (`clab-eda-st-client3`) targeting client2’s IP `10.10.10.2` on port **5201**
  - From client3 targeting client2’s VLAN interface `10.20.2.2` on port **5202**

**Default Test Settings:**

- **Duration:** 10000 seconds
- **Report Interval:** 1 second
- **Parallel Streams:** 10
- **Bandwidth:** 150K
- **MSS:** 1400

**Usage Examples:**

- **Start Traffic:**
    To launch tests from a specific client or from both clients, run:

    ```bash
    ./traffic.sh start client3
    ./traffic.sh start client4
    ./traffic.sh start all
    ```

- **Stop Traffic:**
  To stop tests on a specific client or on all clients, run:
  
    ```bash
    ./traffic.sh stop client3
    ./traffic.sh stop client4
    ./traffic.sh stop all
    ```

## Additional Components

### Containerlab File

The provided containerlab file defines the lab topology. For the Containerlab (clab) variant, it includes:

- Nokia SR Linux nodes (leaf and spine switches)
- Linux clients configured with bonding, VLANs, and iperf3 servers/clients
- Telemetry and logging containers (Alloy, Prometheus, Grafana, Promtail, Loki, Kafka)

For the CX variant, the topology includes only the telemetry and logging containers.

### EDA Configuration

The lab includes several manifest files that define the configuration of EDA apps and the network fabric. For example:

- **Apps Installation (0000_apps.yaml):** Installs the Prometheus exporter (prom-exporter v2.0.0) and the Kafka exporter (kafka-exporter v2.0.1).
- **Edge Interfaces (0009_edge-interfaces.yaml / 0010_edge-interfaces.yaml):** Configure LAG, LLDP, and edge interfaces on SR Linux nodes.
- **TopoLinks (0010_topolinks.yaml / 0009_topolinks.yaml):** Define physical and logical links between network elements.
- **Exporters (0020_exporters.yaml / 0025_exporters.yaml):** Export telemetry metrics (CPU, memory, interface status, routes, etc.) for Prometheus.
- **Syslog (0021_syslog.yaml / 0026_syslog.yaml):** Set up syslog forwarding to a centralized server.
- **Fabric Topology (0030_fabric.yaml):** Establish the Clos fabric connectivity.
- **Virtual Networks (0040_ipvrf2001.yaml and 0041_macvrf1001.yaml):** Configure VRFs and VLANs for traffic segmentation.

For the CX variant, similar manifest files are provided in the manifests/with_cx directory. These components enable automated deployment and comprehensive monitoring of the lab environment.

## Conclusion

The **EDA Telemetry Lab** offers a modern, automated approach to network telemetry and logging by integrating SR Linux with EDA. With fully automated configuration, a powerful monitoring stack leveraging EDA’s Prometheus and Kafka exporters, and flexible deployment options, this lab is an ideal starting point for exploring event-driven network automation.

Happy automating and exploring your network!

---

Connect with us on [Discord](https://eda.dev/discord) for support and community discussions.
