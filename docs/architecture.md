# Argus Infra Architecture

This document provides an in-depth explanation of the Argus Infra components and their interactions, detailing the design choices and how they contribute to a robust and scalable Kubernetes homelab platform.


## 2. Infrastructure Provisioning (Terraform/OpenTofu)

Argus Infra leverages Terraform (or OpenTofu) to provision the underlying virtual machine infrastructure on Hetzner Cloud. This ensures that the infrastructure is defined as code, enabling reproducibility, version control, and automated deployment.

### Key Components:
-   **Hetzner Cloud Project:** The entire infrastructure resides within a dedicated Hetzner Cloud project.
-   **Private Network:** A dedicated private network (`10.0.0.0/16`) and subnet (`10.0.1.0/24`) are created to facilitate secure communication between Kubernetes nodes, isolated from the public internet. This network is crucial for stable internal IP addressing for Kubernetes components.
-   **Virtual Machines:**
    -   **Control Plane Node (`k8s-control`):** A single VM hosts the k3s control plane components (API Server, Controller Manager, Scheduler, embedded etcd). It is the brain of the cluster.
    -   **Worker Nodes (`k8s-worker-X`):** Multiple VMs act as worker nodes, running the `kubelet` and `kube-proxy` to execute application workloads. They are responsible for running containers.
-   **SSH Keys:** SSH keys are managed through Terraform to allow secure access to the VMs for initial setup and troubleshooting. Terraform references existing keys in Hetzner Cloud, it does not manage the key material itself.

## 3. Kubernetes Cluster (k3s)

k3s is chosen as the Kubernetes distribution for its lightweight nature, ease of installation, and suitability for homelab and edge environments. It provides a fully compliant Kubernetes API with a reduced footprint.

### Key Components:
-   **k3s Server:** Runs on the `k8s-control` node, encompassing:
    -   **API Server:** Exposes the Kubernetes API, acting as the front-end for the control plane.
    -   **Controller Manager:** Runs controller processes, which watch the shared state of the cluster through the API server and make changes attempting to move the current state towards the desired state.
    -   **Scheduler:** Assigns pods to nodes based on resource requirements and other constraints.
    -   **Embedded etcd:** A lightweight, embedded datastore for cluster state, ensuring high availability and data consistency.
    -   **CoreDNS:** Provides DNS services for the cluster.
    -   **Traefik:** The default ingress controller for k3s, handling external access to services.
-   **k3s Agent:** Runs on `k8s-worker-X` nodes, encompassing:
    -   **kubelet:** The agent that runs on each node in the cluster. It ensures that containers are running in a Pod.
    -   **kube-proxy:** Maintains network rules on nodes, enabling network communication to your Pods from network sessions inside or outside of your cluster.

## 4. Configuration Management (Ansible)

Ansible is used for post-provisioning configuration of the VMs and for installing and configuring k3s. It automates tasks such as:
-   System updates and package installation.
-   User and SSH key management.
-   Firewall configuration (e.g., opening necessary ports for Kubernetes).
-   k3s installation and cluster joining, ensuring a consistent setup across all nodes.

## 5. GitOps with ArgoCD

ArgoCD is the cornerstone of the GitOps workflow, enabling declarative and automated deployment of applications and cluster configurations. It continuously monitors the `argus-infra` Git repository for changes in Kubernetes manifests and automatically synchronizes the cluster state to match the desired state defined in Git.

### Key Aspects:
-   **Source of Truth:** The Git repository (`k8s/` directory) serves as the single source of truth for all cluster configurations and application deployments. All changes to the cluster state are made via Git commits.
-   **Automated Sync:** ArgoCD automatically detects divergences between the desired state (Git) and the actual state (cluster) and reconciles them, ensuring continuous deployment and self-healing capabilities.
-   **Application of Applications (App-of-Apps):** A hierarchical structure where a root ArgoCD application manages other ArgoCD applications, allowing for modular and scalable management of various components (e.g., core services, monitoring, logging, security).

## 6. Secrets Management (External Secrets Operator & Doppler)

Sensitive information (e.g., API keys, database credentials) is managed securely using a combination of External Secrets Operator (ESO) and Doppler.

### Workflow:
1.  **Doppler:** Stores secrets securely in a centralized, managed service, providing versioning and access control.
2.  **External Secrets Operator:** Deployed within the Kubernetes cluster, ESO fetches secrets from Doppler and injects them as native Kubernetes `Secret` objects. This eliminates the need to store secrets directly in Git.
3.  **Kubernetes Secrets:** Applications consume these Kubernetes `Secret` objects, ensuring that sensitive data is never committed to Git and is handled securely within the cluster.

## 7. Ingress and TLS (NGINX Ingress Controller & cert-manager)

External access to applications within the cluster is managed by an NGINX Ingress Controller, with TLS certificates automatically provisioned and renewed by cert-manager.

### Key Components:
-   **NGINX Ingress Controller:** Routes external HTTP/S traffic to the appropriate services within the Kubernetes cluster based on Ingress resources. It acts as a reverse proxy and load balancer.
-   **cert-manager:** Automates the management and issuance of TLS certificates from various issuing sources like Let's Encrypt. It ensures that applications have valid and up-to-date certificates for secure communication.

## 8. Monitoring and Alerting (Prometheus & Grafana)

To ensure the health and performance of the cluster and deployed applications, Argus Infra integrates Prometheus for metrics collection and alerting, and Grafana for visualization.

### Key Components:
-   **Prometheus:** A powerful open-source monitoring system that collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts if some condition is observed to be true.
-   **Grafana:** An open-source platform for monitoring and observability. It allows you to query, visualize, alert on, and explore your metrics, logs, and traces no matter where they are stored.
