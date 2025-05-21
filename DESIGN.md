# az-bootstrap Design

## Overview

`az-bootstrap` is a PowerShell module to automate Azure and GitHub environment setup for Infrastructure-as-Code (IaC) projects. It is inspired by `azd up` but is focused on secure, OIDC-based, automated deployments and ongoing environment management.

## Architecture & Workflow

- **Template/Target Repo Pattern:**
  - Clones a GitHub template repo to create a new solution repo.
  - Configures the new repo with GitHub environments, secrets, and branch protection.
- **Azure Infra via Bicep:**
  - Uses a subscription-scoped Bicep template (`environment-infra.bicep`) to provision:
    - Resource Group
    - Two Managed Identities (plan/apply)
    - Federated credentials for GitHub OIDC
    - RBAC assignments (Contributor, RBAC Admin)
- **GitHub Configuration:**
  - Sets up environments (e.g., dev-iac-plan, dev-iac-apply), secrets, and policies.
  - Reviewer/team/secret params are optional and skipped if empty.
- **Extensible:**
  - Designed for future support of Azure DevOps, more policies, and additional cloud providers.

## Key Functions

- **Invoke-AzBootstrap:** Orchestrates full bootstrap (repo, infra, branch protection, initial environment).
- **Add-AzBootstrapEnvironment:** Adds a new environment (Azure infra + GitHub config).
- **Remove-AzBootstrapEnvironment:** Removes an environment.
- **Install-GitHubCLI:** Ensures GitHub CLI is available.
- **New-AzBicepDeployment:** Deploys Bicep template (infra, MI, RBAC, FIC).
- **New-GitHubEnvironment/Secrets/Policy:** Manages GitHub environments and policies.

## Design Principles

- Public functions orchestrate workflows; private functions do atomic tasks.
- All state is passed via parameters (no magic globals).
- Idempotent: handle 'already exists' gracefully.
- Cover logic using Pester tests; external calls are mockable.
- Use approved PowerShell verbs for function names.

## Folder Structure

- `public/`: Exported entry points
- `private/`: Internal helpers
- `templates/`: Bicep templates
- `tests/`: Pester tests

## Testing

- Uses [Pester](https://pester.dev/) for unit and integration tests.
- All external calls (az, gh, git) are mockable.
- Run all tests with:

  ```powershell
  set-executionpolicy -scope process -executionpolicy bypass
  Invoke-Pester -Path ./tests/
  ```

## Extensibility & Future Enhancements

- Add support for Azure DevOps and other repo hosts.
- More granular policy and RBAC configuration.
- Interactive wrappers for onboarding.

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

## Release Process

When creating a new release:

1. Update the `ModuleVersion` in `az-bootstrap.psd1` to a higher version than the current one in the PowerShell Gallery.
2. Create a GitHub release, which will trigger the publish workflow.
3. The workflow will automatically check if the version number is higher than the previously published version.
4. If the version number is not higher, the workflow will fail with an error message.
5. If the version check passes, the module will be uploaded to the PowerShell Gallery.

---

For usage instructions, see [README.md](./README.md).
