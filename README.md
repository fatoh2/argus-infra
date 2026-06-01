# Argus Infra

## Project Overview
Argus Infra is the foundational Kubernetes homelab platform for the Argus project. It provides a robust, automated, and GitOps-driven infrastructure for deploying and managing applications. This repository contains all the necessary configurations for provisioning virtual machines, setting up a k3s Kubernetes cluster, and bootstrapping ArgoCD for continuous deployment.

## Architecture Diagram

```
+-------------------+       +-------------------+       +-------------------+
|     Hetzner       |       |     Ansible       |       |      ArgoCD       |
|    Cloud (VMs)    |       |    Controller     |       |    (GitOps)       |
+---------+---------+       +---------+---------+       +---------+---------+
          |                           |                           |
          | Terraform                 | Ansible                   | GitOps
          | Provisioning              | Configuration             | Deployments
          v                           v                           v
+---------+---------+       +---------+---------+       +---------+---------+
|   Virtual Machines  |----->|    k3s Cluster    |<----->|   GitHub Repo   |
| (Ubuntu, Docker)    |       | (Control Plane &  |       | (k8s manifests) |
+---------------------+       |     Agents)       |       +-----------------+
                              +-------------------+
```

## What it Does
- **Automated VM Provisioning**: Uses Terraform to provision virtual machines on Hetzner Cloud.
- **Kubernetes Cluster Setup**: Leverages Ansible to install and configure a k3s Kubernetes cluster.
- **GitOps with ArgoCD**: Bootstraps ArgoCD to manage Kubernetes applications declaratively from Git.
- **Infrastructure as Code**: All infrastructure components are defined as code, enabling version control, reproducibility, and automated deployments.

## Tech Stack
- **Cloud Provider**: Hetzner Cloud
- **Infrastructure Provisioning**: Terraform
- **Configuration Management**: Ansible
- **Kubernetes Distribution**: k3s
- **GitOps**: ArgoCD
- **Container Runtime**: containerd (managed by k3s)
- **Operating System**: Ubuntu Server

## Documentation
- [Setup Guide](docs/setup.md)
- [Architecture Decision Records](docs/adr/)
- [Operational Runbooks](docs/runbooks.md)
