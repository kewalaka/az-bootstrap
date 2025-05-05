# Copilot Instructions for az-bootstrap Module

## Overview

This file provides detailed guidance for AI assistants (and human contributors) working on the `az-bootstrap` PowerShell module. The goal is to ensure future updates are consistent, maintainable, and aligned with the module's design philosophy.

---

## Module Purpose

- **az-bootstrap** automates the setup of Azure infrastructure and GitHub repository environments for Infrastructure-as-Code (IaC) projects.
- It is inspired by `azd up` but is focused on bootstrapping foundational cloud and repository configuration for secure, automated deployments using OIDC and GitHub Actions.
- It provides functionality to create and manage multiple environments (dev, test, prod, etc.) within a project, each with appropriate Azure resources and GitHub environment configurations.

Essentially, it bootstraps both the Azure and GitHub sides needed for a secure, OIDC-based deployment pipeline for a new IaC project, starting from a predefined template, and enables ongoing environment management.

---

## What is the module

The az-bootstrap repository contains a PowerShell module designed to automate the initial setup and ongoing environment management for Infrastructure-as-Code (IaC) projects that use Azure and GitHub. It performs the following main tasks:

- Clones a Template: It takes a GitHub template repository URL (e.g., a starter template for Terraform or Bicep) and creates a new repository from it for your specific project (the "target" repository).
- Provisions Azure Core Infrastructure: It creates an Azure Resource Group and a Managed Identity within your Azure subscription.
- Configures GitHub for OIDC: It sets up GitHub Environments (e.g., 'dev-plan', 'dev-apply', 'prod-plan', 'prod-apply'), configures Federated Credentials on the Azure Managed Identity to trust these environments, and sets necessary secrets (like Azure tenant ID, subscription ID, client ID) in the GitHub environments. This allows GitHub Actions workflows in the target repository to securely authenticate to Azure without needing long-lived secrets.
- Sets up Branch Protection: It configures branch protection rules on the target repository to enforce policies, likely related to the configured environments.
- Assigns RBAC Roles: It grants the created Managed Identity the 'Contributor' and 'RBAC Administrator' roles on the Resource Group, enabling it to deploy and manage resources and permissions within that scope.
- Manages Multiple Environments: It supports adding, configuring, and removing additional environments (dev, test, prod, etc.) after initial setup, with each environment having its own Azure resources and GitHub environments.

---

## Key Features

- Creates a new GitHub repository from a template using `gh repo create --template` (not just cloning).
- Clones the new repository locally for further setup.
- Creates an Azure resource group and managed identity.
- Assigns Contributor and RBAC Administrator roles to the managed identity at the resource group level.
- Sets up federated credentials for GitHub environments (plan, apply, etc.).
- Configures GitHub environments, secrets, and branch protection in the new solution repository.
- Supports ongoing environment management (adding/removing environments).
- Separates branch protection from environment-specific configurations.
- Designed for extensibility (future support for Azure DevOps, more policies, etc.).

---

## Design Principles

- **SOLID Principles:**
  - Each function should have a single responsibility.
  - Functions should be open for extension but closed for modification.
  - Use dependency injection (pass parameters, avoid global state).
  - Favor composition over inheritance (compose workflows from small, testable functions).
- **Separation of Concerns:**
  - Public functions orchestrate workflows.
  - Private functions perform atomic tasks (e.g., create RG, assign RBAC, set secret).
- **Idempotency:**
  - Functions should not fail if resources already exist (handle 'already exists' gracefully).
- **Explicit Parameters:**
  - Avoid reliance on environment variables unless explicitly passed or documented.
- **Error Handling:**
  - Use try/catch and meaningful error messages.
  - Fail early and clearly if prerequisites are missing.
- **Testability:**
  - All logic should be covered by Pester tests.
  - Use mocks for external dependencies (az, gh, git).

---

## Folder Structure

- `public/` — Exported functions (main entry points, e.g., `New-AzBootstrap`, `Add-Environment`).
- `private/` — Internal helpers (not exported, e.g., `New-AzResourceGroup`, `Grant-AzRBACRole`).
- `classes/` — (Optional) PowerShell classes.
- `tests/` — Pester tests for all public and private functions.
- `README.md` — High-level usage and getting started.
- `DESIGN.md` — Detailed design, architecture, and extensibility notes.

---

## Key Functions & Responsibilities

- **New-AzBootstrap** (public): Orchestrates the full bootstrap process. Creates a new GitHub repo from a template, clones it, sets up branch protection, then creates the initial "dev" environment with Azure and GitHub configurations.
- **Add-Environment** (public): Creates a new environment with associated Azure infrastructure and GitHub environment configurations.
- **Remove-Environment** (public): Removes an environment by deleting its GitHub environments and optionally its Azure infrastructure.
- **Install-GitHubCLI** (public): Installs GitHub CLI if not available (downloads if needed).
- **Set-AzBootstrapAzureInfra** (private): Creates RG, managed identity, assigns RBAC, sets up federated creds.
- **Set-GitHubEnvironmentConfig** (private): Creates environments, sets secrets, policies. Accepts explicit Owner/Repo parameters.
- **Set-GitHubBranchProtection** (private): Sets branch protection rules. Separate from environment configuration.
- **Grant-AzRBACRole** (private): Assigns a role to a principal at the RG scope.
- **Get-GitHubRepositoryInfo** (private): Gets repo info from explicit parameters, git, or Codespaces env.
- **Invoke-GitHubCliCommand** (private): Runs a GitHub CLI command.
- **New-AzEnvironmentInfrastructure** (private): Creates the Azure infrastructure for a specific environment.
- **New-AzResourceGroup**, **New-AzManagedIdentity**, **New-AzFederatedCredential**: Atomic Azure resource operations.
- **New-GitHubEnvironment**, **Set-GitHubEnvironmentSecrets**, **Set-GitHubEnvironmentPolicy**, **New-GitHubBranchRuleset**: Atomic GitHub repo operations.

---

## GitHub Environment and Policy Management

- **New-GitHubEnvironment**: Accepts optional ARM parameters (TenantId, SubscriptionId, ClientId). If all are provided, secrets are set automatically for the environment.
- **Set-GitHubEnvironmentSecrets**: Sets ARM secrets for a GitHub environment. Skips secret configuration if any required value is missing.
- **Set-GitHubEnvironmentPolicy**: Accepts both user and team reviewers. Reviewer IDs are resolved automatically. If reviewer arrays are empty, reviewer configuration is skipped. Protected branches default to `main` but can be customized.
- All reviewer/team/secret parameters are optional and skipped if not provided or empty.
- All new/updated functions follow the explicit parameter and no-magic-globals rule.

---

## Update Considerations

- **Always update or add Pester tests for new/changed logic.**
- **Update documentation (README.md, DESIGN.md) if workflows, parameters, or architecture change.**
- **If adding support for new cloud providers or repo hosts, keep logic modular and avoid hard-coding provider-specific details.**
- **If adding new environment policies or secrets, ensure they are parameterized and documented.**
- **If changing RBAC or security logic, review for least-privilege and idempotency.**
- **If updating CLI dependencies (az, gh), ensure compatibility and update Ensure-GhCli if needed.**
- **If adding interactive features, consider keeping them in a wrapper script, not the core module.**
- **Use PowerShell approved verbs for cmdlet names** <https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.5>

---

## Useful Context for LLMs

- The initial workflow is: create new repo from template → clone new repo → set branch protection → create dev environment
- The ongoing workflow is: add/remove environments as needed, each with their own Azure resources and GitHub environment configurations
- Environment types follow the pattern: "{environment}-plan" and "{environment}-apply" (e.g., "dev-plan", "dev-apply", "prod-plan", "prod-apply")
- Branch protection is set once during initial setup and is separate from environment-specific configurations
- All private GitHub functions should accept explicit Owner/Repo parameters for testability and correctness
- Tests should mock `gh repo create` as well as `gh secret`, `gh api`, etc.
- This module should remain cross-platform where possible
- The main use case is IaC project bootstrap for Azure + GitHub, but extensibility is a goal
- All external calls to Azure or GitHub should be mockable for tests
- The module is intended for both human and automated (CI/CD) use
- If in doubt, prefer explicit, parameterized, and testable code

---

## Example Update Workflow

1. Add or update a function in `private/` or `public/` as needed.
2. Add or update Pester tests in `tests/`.
3. Update `az-bootstrap.psm1` if new functions need to be loaded.
4. Update documentation if the public interface or workflow changes.
5. Run all tests (`Invoke-Pester -Path ./az-bootstrap/tests`).
6. Commit with a clear message describing the change and its rationale.

---

## Contact & Ownership

- If you are an LLM, always check for the latest context in this file and the module docs.
- If you are a human, please review open issues and PRs before making major changes.

---

## End of Copilot Instructions
