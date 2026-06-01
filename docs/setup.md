# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl controls the Kubernetes cluster manager.



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
  -version      An alias for the "version" subcommand. and  directories for instructions on provisioning VMs and installing k3s.

2.  **Bootstrap ArgoCD**

    Run the bootstrap script to install ArgoCD and set up the root app-of-apps.

    Applying ArgoCD install manifests...
    

3.  **Retrieve ArgoCD Admin Password**

    

4.  **Access ArgoCD UI**

    
    Then navigate to https://localhost:8080 in your browser. The username is .


## Next Steps

- Add child application manifests to  for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the  branch of the  repository. ArgoCD will automatically sync them.
- For example, to add the  application, you would create a file like  and commit it.
