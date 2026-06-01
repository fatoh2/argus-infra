# 0002 - Decision: k3s vs kubeadm for Kubernetes Cluster

## Status
Accepted

## Context
When establishing the Kubernetes homelab platform for Argus Infra, a key decision was the choice of Kubernetes distribution. The primary contenders were a full-fledged Kubernetes deployment using `kubeadm` and a lightweight distribution like `k3s`.

## Decision
We decided to use **k3s** for the Argus Infra Kubernetes homelab.

## Rationale
The decision to use k3s was based on the following factors:

1.  **Lightweight and Resource Efficient**: k3s is designed for edge, IoT, and homelab environments, making it significantly lighter on resources compared to a full kubeadm installation. This is crucial for a homelab running on potentially constrained Hetzner VPS instances.
2.  **Simplified Installation and Management**: k3s offers a single binary installation, greatly simplifying the setup and ongoing management. This aligns with the goal of an automated and easily reproducible infrastructure.
3.  **Reduced Operational Overhead**: With k3s, many components that require manual configuration in kubeadm (e.g., etcd, CNI, CoreDNS) are bundled and pre-configured, reducing the operational burden.
4.  **Sufficient Features for Homelab**: For a homelab environment, k3s provides all the necessary Kubernetes features without the complexity of a full-scale enterprise deployment.
5.  **Community Support**: k3s has a strong and active community, ensuring good support and ongoing development.

While `kubeadm` offers more control and is suitable for production-grade, highly customized clusters, its complexity and higher resource requirements were deemed unnecessary for the initial Argus homelab platform. The benefits of simplicity and efficiency offered by k3s outweighed the need for fine-grained control in this context.

## Consequences
-   **Pros**: Faster setup, lower resource consumption, easier maintenance, reduced complexity.
-   **Cons**: Potentially less control over individual Kubernetes components (though sufficient for homelab), might require adaptation if migrating to a full-scale Kubernetes in the future (though k3s is CNCF certified).
