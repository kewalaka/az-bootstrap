## What is the module

The az-bootstrap repository contains a PowerShell module designed to automate the initial setup and ongoing environment management for Infrastructure-as-Code (IaC) projects that use Azure and GitHub. It performs the following main tasks:

- Clones a Template: It takes a GitHub template repository URL (e.g., a starter template for Terraform or Bicep) and creates a new repository from it for your specific project (the "target" repository).
- Provisions Azure Core Infrastructure via Bicep: It deploys an Azure Resource Group and **two** Managed Identities (one for plan, one for apply) within your Azure subscription using a subscription-scoped Bicep template (`environment-infra.bicep`). This template leverages AVM modules.
- Configures GitHub for OIDC: It sets up GitHub Environments (e.g., 'dev-iac-plan', 'dev-iac-apply', 'prod-iac-plan', 'prod-iac-apply'), configures Federated Credentials on the Azure Managed Identities to trust these environments, and sets necessary secrets (like Azure tenant ID, subscription ID, client IDs) in the GitHub environments. This allows GitHub Actions workflows in the target repository to securely authenticate to Azure without needing long-lived secrets.
// ... rest of the section ...

## Key Features

- Creates a new GitHub repository from a template using `gh repo create --template`.
- Clones the new repository locally for further setup.
- Creates Azure infrastructure (Resource Group, **two** Managed Identities - one for plan, one for apply) using a subscription-scoped Bicep template (`environment-infra.bicep`) which utilizes AVM modules.
- Assigns Contributor and "Role Based Access Control Administrator" roles to the managed identities at the resource group level via Bicep.
- Sets up federated credentials for GitHub environments (plan, apply, etc.) on the appropriate Managed Identities via Bicep.
// ... rest of the section ...

## Key Functions & Responsibilities

- **Invoke-AzBootstrap** (public): Orchestrates the full bootstrap process. Creates a new GitHub repo from a template, clones it, sets up branch protection, then creates the initial "dev" environment.
  - Key parameters for initial Azure setup include `ResourceGroupName` (optional), `PlanManagedIdentityName` (optional), `ApplyManagedIdentityName` (optional).
- **Add-AzBootstrapEnvironment** (public): Creates a new environment with associated Azure infrastructure (via Bicep) and GitHub environment configurations.
  - Key parameters include `PlanManagedIdentityName` (mandatory), `ApplyManagedIdentityName` (mandatory).
- **Remove-AzBootstrapEnvironment** (public): Removes an environment by deleting its GitHub environments and optionally its Azure infrastructure.
- **Install-GitHubCLI** (public): Installs GitHub CLI if not available (downloads if needed).
- **New-AzEnvironmentInfrastructure** (private): Orchestrates the deployment of the `environment-infra.bicep` template at the subscription scope. This Bicep template is responsible for creating/updating the Resource Group, the plan Managed Identity, the apply Managed Identity, assigning RBAC roles, and setting up federated credentials.
  - Key parameters include `PlanManagedIdentityName` (mandatory), `ApplyManagedIdentityName` (mandatory).
// ... rest of the section ...

## Useful Context for LLMs

// ... existing context ...

- Azure infrastructure is primarily provisioned by `New-AzEnvironmentInfrastructure` calling `az deployment sub create` with the `templates/environment-infra.bicep` file.
- The Bicep template handles RG creation, creation of **two** MIs (plan and apply), federated credentials for both, and RBAC assignments (Contributor, Role Based Access Control Administrator) for both.
// ... rest of the context ...
