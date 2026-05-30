# Argus Infra Runbooks

## Provision the homelab K8s VMs (Terraform)

Provisions 1 control-plane + 2 worker Hetzner Cloud VMs on a private network.

### Prerequisites
- Terraform/OpenTofu >= 1.5
- A Hetzner Cloud API token (Project > Security > API Tokens)
- An SSH key already uploaded to the Hetzner project

### Steps
```bash
cd terraform/environments/homelab
cp terraform.tfvars.example terraform.tfvars   # gitignored — never commit
# edit terraform.tfvars: set hcloud_token and ssh_key_name

terraform init
terraform plan      # review the diff before applying
terraform apply     # creates the network, subnet, and 3 VMs
```

### Outputs
- `control_plane_ip` — public IPv4 of `k8s-control`
- `worker_ips` — map of worker name → public IPv4
- `ssh_commands` — ready-to-use `ssh root@<ip>` per node

### Addressing
| Node          | Private IP  |
|---------------|-------------|
| k8s-control   | 10.0.1.10   |
| k8s-worker-1  | 10.0.1.11   |
| k8s-worker-2  | 10.0.1.12   |

Network `10.0.0.0/16`, subnet `10.0.1.0/24` (zone `eu-central`).

### Teardown
`terraform destroy` is destructive and MUST be confirmed by the user in Telegram
before running (see CLAUDE.md). Never run it unattended.
