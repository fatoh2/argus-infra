# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl access to the Kubernetes cluster.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/

Ensure the  environment variable is set if your kubeconfig file is not at the default location ().

## Steps

1.  **Provision VMs and Install k3s (if not already done)**

    Refer to the Usage: terraform [global options] <subcommand> [args]

The available commands for execution are listed below.
The primary workflow commands are given first, followed by
less common or more advanced commands.

Main commands:
  init          Prepare your working directory for other commands
  validate      Check whether the configuration is valid
  plan          Show changes required by the current configuration
  apply         Create or update infrastructure
  destroy       Destroy previously-created infrastructure

All other commands:
  console       Try Terraform expressions at an interactive command prompt
  fmt           Reformat your configuration in the standard style
  force-unlock  Release a stuck lock on the current workspace
  get           Install or upgrade remote Terraform modules
  graph         Generate a Graphviz graph of the steps in an operation
  import        Associate existing infrastructure with a Terraform resource
  login         Obtain and save credentials for a remote host
  logout        Remove locally-stored credentials for a remote host
  metadata      Metadata related commands
  modules       Show all declared modules in a working directory
  output        Show output values from your root module
  providers     Show the providers required for this configuration
  query         Search and list remote infrastructure with Terraform
  refresh       Update the state to match remote systems
  show          Show the current state or a saved plan
  stacks        Manage HCP Terraform stack operations
  state         Advanced state management
  taint         Mark a resource instance as not fully functional
  test          Execute integration tests for Terraform modules
  untaint       Remove the 'tainted' state from a resource instance
  version       Show the current Terraform version
  workspace     Workspace management

Global options (use these before the subcommand, if any):
  -chdir=DIR    Switch to a different working directory before executing the
                given subcommand.
  -help         Show this help output or the help for a specified subcommand.
  -version      An alias for the "version" subcommand. directory for VM provisioning (e.g., ) and the  directory for k3s installation (e.g., ).

2.  **Bootstrap ArgoCD**

    Apply the following commands to install ArgoCD and set up the root app-of-apps.

    Applying ArgoCD install manifests...
    
    Wait for ArgoCD pods to be ready:
    
    Apply the root app-of-apps manifest:
    

3.  **Retrieve ArgoCD Admin Password**

    After the bootstrap script completes, it will print the command to retrieve the initial admin password. Run it:
    

4.  **Access ArgoCD UI**

    Port-forward the ArgoCD server to access the UI:
    
    The default username for the ArgoCD UI is .

## Next Steps

- Review and customize the existing child application manifests in  and add any additional ones for your specific workloads (e.g., monitoring, databases, ingress, security).
- If child application source paths (e.g., ) are initially empty or non-existent, ArgoCD applications targeting these paths will show as  or  until content is added to those paths.
- Commit these changes to the  branch of the  repository. ArgoCD will automatically sync them.
