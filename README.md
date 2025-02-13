# EDA Telemetry Lab
[![Discord][discord-svg]][discord-url]

[discord-svg]: https://gitlab.com/rdodin/pics/-/wikis/uploads/b822984bc95d77ba92d50109c66c7afe/join-discord-btn.svg
[discord-url]: https://discord.gg/7nJc5hh8


The **EDA Telemetry Lab** demonstrates how to leverage SR Linux’s full 100% YANG telemetry support integrated with [EDA (Event Driven Automation)](https://docs.eda.dev/). In this lab, SR Linux nodes are dynamically configured via EDA and integrated into a modern telemetry and logging stack that includes Prometheus, Grafana, Promtail, Loki, and Kafka exporters for alarms and deviations.

<p align="center">
  <img src="./docs/dashboard.png" alt="Drawio Example">
</p>


> **Key Benefits:**
> - **Automated Configuration:** No manual startup configs or gnmic setup—EDA handles it all.
> - **Comprehensive Telemetry:** SR Linux streams full YANG telemetry data via EDA’s Prometheus exporter.
> - **Enhanced Alarms & Deviations:** EDA’s Kafka exporter forwards alarms and deviations for proactive monitoring.
> - **Flexible Deployment:** Choose between a Containerlab (clab) topology or a simulation-based CX deployment.

---

## Goals

- **EDA-Driven Configuration:** Automate SR Linux configuration and telemetry subscriptions with EDA.
- **Modern Telemetry Stack:** Export telemetry data using EDA’s Prometheus exporter and monitor alarms/deviations via the Kafka exporter.
- **Enhanced Logging:** Capture and aggregate system logs using Promtail and Loki.
- **Versatile Deployment Options:** Deploy with either Containerlab (clab) for live traffic or CX (Simulation Platform) for license-flexible testing.
- **Live Traffic Insights:** Generate and control iperf3 traffic to see dynamic network metrics in action.

---

## Lab Components

- **Fabric:** A Clos topology of Nokia SR Linux nodes.
- **Telemetry:** SR Linux nodes stream full YANG telemetry data. EDA exports these metrics via its Prometheus exporter and sends alarms/deviations using its Kafka exporter.
- **Visualization:** Grafana dashboards (with the [Flow Plugin](https://grafana.com/grafana/plugins/andrewbmchugh-flow-panel/)) provide real-time insights into network metrics.
- **Alarms:** Data is collected by Promtail and aggregated in Loki, with logs viewable in Grafana.
- **Traffic Generation:** Use iperf3 tests and provided scripts to simulate live traffic across the network.

---

## Deployment Variants

There are two variants for deploying the lab.

### Variant 1: Containerlab (clab)
> [!IMPORTANT]
> **EDA Installation Mode:** This lab **requires EDA to be installed with `Simulate=False`**. Ensure that your EDA deployment is configured accordingly.
>
> **Hardware License:** A valid **`hardware license` for EDA version 24.12.1** is mandatory for using this connector tool.

1. **Initialize the Lab Configuration:**
   - Run the provided `init.sh` script. When prompted, enter your EDA IP address. This will update files like `configs/prometheus/prometheus.yml`.

2. **Install Required Tools:**
   - Execute the following commands:
        ```
        curl -LsSf https://astral.sh/uv/install.sh | sh
        ```
        ```
        uv tool install git+https://github.com/eda-labs/clab-connector.git
        ```

3. **Integrate Containerlab with EDA:**
   - Run:
        ```
        clab-connector integrate \
        --topology-data clab-eda-st/topology-data.json \
        --eda-url https://<eda-ip>
        ```
      > [!TIP]
      > Check [Clab Connetor](https://github.com/eda-labs/clab-connector) for more details on the clab-connector options.

4. **Deploy the Lab:**
   - Apply the manifests:
        ```
        kubectl apply -f manifests/with_clab
        ```
5. **Enjoy Your Lab!**

### Variant 2: CX (Simulation Platform)
> [!NOTE]
>  Works without any license but its limited in traffic generation.

1. **Initialize the Lab Configuration:**
   - Run the provided `init.sh` script to update your configuration files with the EDA IP address.

2. **Bootstrap the Namespace in EDA:**
   - Execute:
        ```
        kubectl exec -n eda-system $(kubectl get pods -n eda-system | grep eda-toolbox | awk '{print $1}') -- edactl namespace bootstrap clab-eda-st
        ```
3. **Deploy the Lab:**
   - Apply the manifests:
        ```
        kubectl apply -f manifests/with_cx
        ```
4. **Enjoy Your Lab!**

---


## Accessing Network Elements in clab

- **SR Linux Nodes:**
  Access these devices via SSH using the management IP addresses or hostnames (e.g., ssh admin@leaf1 or ssh admin@spine1).

- **Linux Clients:**
  Although SSH is not enabled by default, you can access them with:
     docker exec -it client1 bash

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

- **SR Linux Telemetry:**
  Nodes stream full YANG telemetry data.
- **EDA Exporters:**
  - **Prometheus Exporter:** EDA exports detailed telemetry metrics to Prometheus.
  - **Kafka Exporter:** Alarms and deviations are forwarded via EDA’s Kafka exporter, enabling proactive monitoring and alerting.
- **Prometheus:**
  Stores the telemetry data. The configuration (located in `configs/prometheus/prometheus.yml`) is updated during initialization.
- **Grafana:**
  Visualize metrics and dashboards at http://grafana:3000. For admin tasks, use admin/admin.

### Logging

- **Promtail & Loki:**
  Collect and aggregate SR Linux syslogs (e.g., BGP events, interface state changes). Logs are accessible and filterable via Grafana.
- **Prometheus UI:**
  Check out real-time graphs at http://prometheus:9090/graph.

---

## Traffic Generation & Control

The lab includes a traffic script (named **traffic.sh**) that launches bidirectional iperf3 tests between designated clients.

**Test Pairs Configured:**
- **Client4 to Client1:**
  - From client4 (`clab-eda-st-client4`) targeting client1’s IP `10.10.10.1` on port **5201**
  - From client4 targeting client1’s VLAN interface `10.20.1.1` on port **5202**

- **Client3 to Client2:**
  - From client3 (`clab-eda-st-client3`) targeting client2’s IP `10.10.10.2` on port **5201**
  - From client3 targeting client2’s VLAN interface `10.20.2.2` on port **5202**

**Default Test Settings (modifiable via environment variables):**
- **Duration:** 10000 seconds
- **Report Interval:** 1 second
- **Parallel Streams:** 10
- **Bandwidth:** 150K (applies only to UDP tests; ignored for TCP)
- **MSS:** 1400

**Usage Examples:**

- **Start Traffic:**
  To launch tests from a specific client or from both clients, run:

        ./traffic.sh start client3
        ./traffic.sh start client4
        ./traffic.sh start all

- **Stop Traffic:**
  To stop tests on a specific client or on all clients, run:

        ./traffic.sh stop client3
        ./traffic.sh stop client4
        ./traffic.sh stop all


---

## Additional Components

### Containerlab File

The provided containerlab file defines the lab topology. For the Containerlab (clab) variant, it includes:
- Nokia SR Linux nodes (leaf and spine switches)
- Linux clients configured with bonding, VLANs, and iperf3 servers/clients
- Telemetry and logging containers (telegraf, Prometheus, Grafana, Promtail, Loki, Kafka, syslog)

For the CX variant, the topology includes only the telemetry and logging containers.

---

## Conclusion

The **EDA Telemetry Lab** offers a modern, automated approach to network telemetry and logging by integrating SR Linux with EDA. With fully automated configuration, a powerful monitoring stack leveraging EDA’s Prometheus and Kafka exporters, and flexible deployment options, this lab is an ideal starting point for exploring event-driven network automation.

Happy automating and exploring your network!

---

Connect with us on [Discord](https://discord.gg/7nJc5hh8) for support and community discussions.
