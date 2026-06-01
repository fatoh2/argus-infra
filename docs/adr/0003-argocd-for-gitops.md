# 0003 - Decision: ArgoCD for GitOps

## Status
Accepted

## Context
To implement a robust GitOps workflow for managing Kubernetes applications within the Argus Infra homelab, a tool was needed to synchronize Kubernetes manifests from Git repositories to the cluster. The primary options considered were ArgoCD and Flux CD.

## Decision
We decided to use **ArgoCD** for implementing GitOps in Argus Infra.

## Rationale
The choice of ArgoCD was driven by the following considerations:

1.  **Rich UI and User Experience**: ArgoCD provides an intuitive and comprehensive web UI that makes it easy to visualize application states, synchronize resources, and perform rollbacks. This is particularly beneficial for a homelab environment where quick insights and manual interventions might be needed during development and testing.
2.  **Declarative Management**: ArgoCD fully embraces declarative management, continuously monitoring Git repositories for desired state and automatically applying changes to the cluster.
3.  **Application Health Monitoring**: It offers excellent capabilities for monitoring the health of deployed applications, providing clear indicators of resource status.
4.  **Rollback Capabilities**: ArgoCD's built-in rollback features allow for easy reversion to previous application versions, enhancing operational safety.
5.  **Active Community and Ecosystem**: ArgoCD has a very active community, extensive documentation, and a rich ecosystem of integrations.
6.  **Authentication and Authorization**: It provides robust authentication and authorization mechanisms suitable for managing access in a team environment.

While Flux CD is also a strong contender and offers similar core GitOps functionalities, ArgoCD's superior UI and slightly more mature feature set for application management (especially for visualization and manual operations when needed) made it the preferred choice for Argus Infra.

## Consequences
-   **Pros**: Enhanced visibility into application deployments, simplified management of Kubernetes resources, robust rollback capabilities, strong community support.
-   **Cons**: Adds another component to manage within the cluster, requires initial setup and configuration.
