# az-bootstrap Design

## Overview

`az-bootstrap` is a PowerShell module designed to automate the setup of Azure and GitHub environments for Infrastructure-as-Code (IaC) projects. It is inspired by the experience of using `azd up`, but is focused on bootstrapping the foundational cloud and repository configuration for secure, automated deployments.

## Template/Target Repository Pattern

- **Source (Template) Repository:**
  - A GitHub repository (such as [terraform-azure-starter-template](https://github.com/kewalaka/terraform-azure-starter-template)) that serves as a starting point for new IaC projects.
  - This repository is cloned by the module to create a new solution repository.
- **Target (Solution) Repository:**
  - The new repository created from the template, where the DevOps engineer will build their solution.
  - The module configures this repository with GitHub environments, secrets, and branch protections.

## Key Features

- **Repo Cloning:** Clones a specified GitHub template repository to a local directory.
- **Azure Infra:** Creates a resource group and managed identity, and configures federated credentials for OIDC-based GitHub Actions workflows.
- **GitHub Environments:** Creates GitHub environments (PLAN, APPLY, etc.), sets secrets, and applies branch protection and deployment policies.
- **Extensible:** Designed to support both GitHub and Azure DevOps in the future.
- **RBAC Assignment:** Grants Contributor and RBAC Administrator roles to the managed identity at the resource group level for full deployment and access control capabilities.

## Updated Features

- **Environment Management:**
  - Added support for creating and managing multiple environments (e.g., dev, test, prod).
  - Each environment has its own Azure resources and GitHub configurations.
  - Environments follow a default naming pattern `{environment}-iac-plan` and `{environment}-iac-apply`, this can be overriden by parameters.

## Architecture

- **Public Interface:**
  - `Invoke-AzBootstrap`: Orchestrates the full bootstrap process.
  - `Add-AzBootstrapEnvironment`: Creates a new environment with associated Azure infrastructure and GitHub environment configurations.
  - `Remove-AzBootstrapEnvironment`: Removes an environment by deleting its GitHub environments and optionally its Azure infrastructure.
- **Private Functions:**
  - `Get-GitHubRepositoryInfo`, `Invoke-GitHubCliCommand`, `New-AzResourceGroup`, `New-AzManagedIdentity`, `New-AzFederatedCredential`, `New-GitHubEnvironment`, `Set-GitHubEnvironmentSecrets`, `Set-GitHubEnvironmentPolicy`, `New-GitHubBranchRuleset`, etc.
- **Separation of Concerns:**
  - Each function is responsible for a single task, making the module easy to maintain and extend.

## Updated Flow Diagram

```mermaid
flowchart TD
    A[User runs Invoke-AzBootstrap] --> B[Create new solution repo based on supplied GitHub template]
    B --> C[Clone repo locally to target directory]
    C --> D[Create Azure Resource Group, Managed Identity, set RBAC]
    D --> E[Set up GitHub Environments, Secrets, Branch Protections in solution repo]
    E --> F[Add or manage additional environments as needed]
    F --> G[Ready for IaC development!]
```

## GitHub Environment and Policy Management

- **New-GitHubEnvironment**: Now supports optional ARM parameters (TenantId, SubscriptionId, ClientId). If all are provided, it will automatically set these as secrets in the created environment using `Set-GitHubEnvironmentSecrets`.
- **Set-GitHubEnvironmentSecrets**: Robustly sets ARM secrets for a given environment, skipping secret configuration if any required value is missing.
- **Set-GitHubEnvironmentPolicy**: Supports both user and team reviewers. Reviewer IDs are resolved automatically. If no reviewers are provided, reviewer configuration is skipped. Protected branches default to `main` but can be customized.
- All reviewer/team/secret parameters are optional and, if not provided or empty, the related configuration is skipped.

## Parameter Handling Improvements

- All public and private functions now use sensible defaults for optional parameters.
- Reviewer and team arrays, as well as ARM secret parameters, are optional and skipped if empty.
- No use of magic globals; all state is passed explicitly or via standard environment variables.

## Extensibility

- The module is structured to allow easy addition of new cloud providers, repo hosts, or environment policies.
- Private functions can be extended or replaced as requirements evolve.

## Security

- Uses OIDC federated credentials for secure, passwordless deployments from GitHub Actions.
- Secrets are set per-environment in GitHub for least-privilege access.

## Future Enhancements

- Support for Azure DevOps and other repo hosts
- More granular policy and RBAC configuration
- Interactive wrappers for user-friendly onboarding

## Testing with Pester

This module uses [Pester](https://pester.dev/) for unit and integration testing.

To run the tests:

- Open a PowerShell terminal.
- Navigate to the root directory of the `az-bootstrap` module.
- Run the following command:

```powershell
set-executionpolicy -scope process -executionpolicy bypass
Invoke-Pester -Path ./tests/
# or to exclude a specific test
Invoke-Pester -Path ./tests/ -ExcludePath "*NewAzBootstrap*"
```

This command will discover and execute all test files (`*.Tests.ps1`) within the `tests` directory.

## Updated Testing Instructions

To test the new environment management features:

```powershell
# Test adding a new environment
Invoke-Pester -Path ./tests/Test-AddEnvironment.Tests.ps1

# Test removing an environment
Invoke-Pester -Path ./tests/Test-RemoveEnvironment.Tests.ps1
```

---

For usage instructions, see [README.md](./README.md).
