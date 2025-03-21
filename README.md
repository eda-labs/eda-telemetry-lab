# EDA Telemetry Lab

[![Discord][discord-svg]][discord-url]

[discord-svg]: https://gitlab.com/rdodin/pics/-/wikis/uploads/b822984bc95d77ba92d50109c66c7afe/join-discord-btn.svg
[discord-url]: https://eda.dev/discord

The **EDA Telemetry Lab** demonstrates how to leverage full 100% YANG telemetry support integrated with [EDA (Event Driven Automation)](https://docs.eda.dev/). In this lab, [Nokia SR Linux](https://learn.srlinux.dev/) nodes are dynamically configured via EDA and integrated into a modern telemetry and logging stack that includes Prometheus, Grafana, Promtail, Loki, Alloy and Kafka exporters for alarms and deviations.

<https://github.com/user-attachments/assets/38efb03a-c4aa-4a52-820a-b96d8a7005ea>

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

There are two variants for deploying the lab:

- **Using Containerlab**:
    The simulated SR Linux nodes, client containers and the telemetry stack are deployed using Containerlab. This deployment variant requires a license for EDA, as the simulated SR Linux nodes are deployed outside of EDA.  
    On the positive side, using Containerlab allows for live traffic generation using iperf.
- **Using CX** (EDA Simulation Platform):
    The simulated SR Linux nodes are spawned in EDA CX and thus do not require a license. The telemetry stack for convenience is deployed using Containerlab. This deployment variant does not require a license but does not support traffic generation with iperf.

This README focuses on the Containerlab deployment variant as it leverages iperf-generated traffic for demonstration purposes. See [cx/README.md](cx/README.md) for the CX deployment variant.

> [!IMPORTANT]
> **EDA Installation Mode:** This lab requires EDA to be installed in the [`Simulate=False`][sim-false-doc] mode. Ensure that your EDA deployment is configured accordingly.
>
> **Hardware License:** A valid `hardware license` for EDA version 24.12 is mandatory for using this lab with Containerlab.

[sim-false-doc]: https://docs.eda.dev/user-guide/containerlab-integration/#installing-eda

1. **Ensure `kubectl` is installed and configured:**
    To test if `kubectl` is installed and configured, run:

    ```bash
    kubectl -n eda-system get engineconfig engine-config \
    -o jsonpath='{.status.run-status}{"\n"}'
    ```

    You should see `Started` in the output.

2. **Initialize the Lab Configuration:**

    Run the provided `init.sh` which does the following:

    - ensures `uv` and `clab-connector` tools are installed
    - retrieves the EDA IP and sets it in the `configs/prometheus/prometheus.yml` files.
    - save EDA API address in a `.eda_api_address` file.

    ```bash
    ./init.sh
    ```

3. **Deploy containerlab topology:**

    Run `containerlab deploy` to deploy the lab.

4. **Install the EDA Apps (Prometheus and Kafka):**

    Run:

    ```bash
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

    ```bash
    kubectl apply -f manifests
    ```

7. **Enjoy Your Lab!**

> [!TIP]
> **Shutdown interfaces via WebUI:** Client 1, exposes the port 8080 for the WebUI. You can use the WebUI to shutdown interfaces on the SR Linux nodes.

## Accessing Network Elements

- **SR Linux Nodes:**
  Access these devices via SSH using the management IP addresses or hostnames (e.g., `ssh clab-eda-st-leaf2`).

- **Linux Clients:**
  Access client-emulating container via SSH: e.g. `ssh user@clab-eda-st-server3` (password: `multit00l`).

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

- **Server4 to Server1:**
  - From server4 (`clab-eda-st-server4`) targeting server1’s IP `10.10.10.1` on port **5201**
  - From server4 targeting server1’s VLAN interface `10.20.1.1` on port **5202**

- **Server3 to Server2:**
  - From server3 (`clab-eda-st-server3`) targeting server2’s IP `10.10.10.2` on port **5201**
  - From server3 targeting server2’s VLAN interface `10.20.2.2` on port **5202**

**Default Test Settings:**

- **Duration:** 10000 seconds
- **Report Interval:** 1 second
- **Parallel Streams:** 10
- **Bandwidth:** 120K
- **MSS:** 1400

**Usage Examples:**

- **Start Traffic:**
    To launch tests from a specific client or from both clients, run:

    ```bash
    ./traffic.sh start server3
    ./traffic.sh start server4
    ./traffic.sh start all
    ```

- **Stop Traffic:**
  To stop tests on a specific client or on all clients, run:

    ```bash
    ./traffic.sh stop server3
    ./traffic.sh stop server4
    ./traffic.sh stop all
    ```

## EDA Configuration

The lab includes several manifest files that define the configuration of EDA apps and the network fabric:

- **Apps Installation (0000_apps.yaml):** Installs the Prometheus exporter (prom-exporter v2.0.0) and the Kafka exporter (kafka-exporter v2.0.1).
- **Interfaces (0009_interfaces.yaml):** Configure LAG interfaces on SR Linux leaf switches.
- **TopoLinks (0010_topolinks.yaml):** Define LAG topology links hanging off of leaf switches towards the servers.
- **Prometheus Exporters (0020_prom_exporters.yaml):** Prometheus Exporter configuration to stream telemetry metrics (CPU, memory, interface status, routes, etc.).
- **Kafka Exporter (0021_kafka_exporter.yaml):** Kafka Producer configuration to stream alarms and deviations.
- **JSON-RPC server config (0025_json-rpc.yaml):** Configlet with the JSON-RPC server configuration to enable port shutdown automation.
- **Syslog (0026_syslog.yaml):** Set up syslog forwarding to a centralized server.
- **Fabric Topology (0030_fabric.yaml):** The Clos-based fabric configuration with eBPG/iBGP underlay/overlay.
- **Virtual Networks (0040_ipvrf2001.yaml and 0041_macvrf1001.yaml):** Virtual networks configuration to support IP VRF and MAC VRF services.

## Conclusion

The **EDA Telemetry Lab** offers a modern, automated approach to network telemetry and logging by integrating SR Linux with EDA. With fully automated configuration, a powerful monitoring stack leveraging EDA’s Prometheus and Kafka exporters, and flexible deployment options, this lab is an ideal starting point for exploring event-driven network automation.

Happy automating and exploring your network!

---

Connect with us on [Discord](https://eda.dev/discord) for support and community discussions.
