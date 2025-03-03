# Using EDA CX

The EDA Telemetry Lab can be deployed using the EDA CX (Simulation Platform) variant. This variant does not require a license but does not support traffic generation with iperf.

To deploy the lab using CX, follow these steps:

1. **Initialize the Lab Configuration:**

    Run the provided `init.sh` script to update your configuration files with the EDA IP address.

2. **Deploy the topology:**

    While the lab uses CX to simulate SR Linux nodes, the telemetry stack for convenience is deployed using Containerlab.

    Run `containerlab deploy -t ./cx/eda-st-cx.clab.yaml` to deploy the lab.

3. **Bootstrap the Namespace in EDA:**

    Execute:

    ```bash
    kubectl exec -n eda-system $(kubectl get pods -n eda-system | grep eda-toolbox | awk '{print $1}') -- edactl namespace bootstrap clab-eda-st
    ```

4. **Install the EDA Apps (Prometheus and Kafka):**

    Run:

    ```bash
    kubectl apply -f ./manifests/0000_apps.yaml
    ```

    **TIP:** Depending on your setup this can take a couple of seconds/minutes. Please check in the EDA UI if the apps are installed.

5. **Deploy the Lab:**

    Apply the manifests:

    ```
    kubectl apply -f ./cx/manifests
    ```

6. **Enjoy Your Lab!**

## Accessing Network Elements in cx (Simulation Platform)

- **SR Linux Nodes:**
  Access these devices via the SR Linux CLI using the following command:

    ```bash
    kubectl get pods -n eda-system | grep leaf1 | awk '{print "kubectl exec -it -n eda-system " $1 " -- sudo sr_cli"}'
    ```

> [!NOTE]
> Replace grep leaf1 with the desired node name.
