# Copilot Instructions for az-bootstrap Module

## Overview

This file provides detailed guidance for AI assistants (and human contributors) working on the `az-bootstrap` PowerShell module. The goal is to ensure future updates are consistent, maintainable, and aligned with the module's design philosophy.

---

## Module Purpose

- **az-bootstrap** automates the setup of Azure infrastructure and GitHub repository environments for Infrastructure-as-Code (IaC) projects.
- It is inspired by `azd up` but is focused on bootstrapping foundational cloud and repository configuration for secure, automated deployments using OIDC and GitHub Actions.

Essentially, it bootstraps both the Azure and GitHub sides needed for a secure, OIDC-based deployment pipeline for a new IaC project, starting from a predefined template.

---

## What is the module

The az-bootstrap repository contains a PowerShell module designed to automate the initial setup for Infrastructure-as-Code (IaC) projects that use Azure and GitHub. It performs the following main tasks:

- Clones a Template: It takes a GitHub template repository URL (e.g., a starter template for Terraform or Bicep) and creates a new repository from it for your specific project (the "target" repository).
- Provisions Azure Core Infrastructure: It creates an Azure Resource Group and a Managed Identity within your Azure subscription.
- Configures GitHub for OIDC: It sets up GitHub Environments (e.g., 'plan', 'apply'), configures Federated Credentials on the Azure Managed Identity to trust these environments, and sets necessary secrets (like Azure tenant ID, subscription ID, client ID) in the GitHub environments. This allows GitHub Actions workflows in the target repository to securely authenticate to Azure without needing long-lived secrets.
- Sets up Branch Protection: It configures branch protection rules on the target repository to enforce policies, likely related to the configured environments.
- Assigns RBAC Roles: It grants the created Managed Identity the 'Contributor' and 'User Access Administrator' roles on the Resource Group, enabling it to deploy and manage resources and permissions within that scope.

---

## Key Features

- Creates a new GitHub repository from a template using `gh repo create --template` (not just cloning).
- Clones the new repository locally for further setup.
- Creates an Azure resource group and managed identity.
- Assigns Contributor and User Access Administrator (RBAC) roles to the managed identity at the resource group level.
- Sets up federated credentials for GitHub environments (PLAN, APPLY, etc.).
- Configures GitHub environments, secrets, and branch protection in the new solution repository.
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

- `public/` — Exported functions (main entry points, e.g., `New-AzBootstrap`).
- `private/` — Internal helpers (not exported, e.g., `New-AzResourceGroup`, `Grant-RBACRole`).
- `classes/` — (Optional) PowerShell classes.
- `tests/` — Pester tests for all public and private functions.
- `README.md` — High-level usage and getting started.
- `DESIGN.md` — Detailed design, architecture, and extensibility notes.

---

## Key Functions & Responsibilities

- **New-AzBootstrap** (public): Orchestrates the full bootstrap process. Creates a new GitHub repo from a template, clones it, then sets up Azure and GitHub configuration.
- **Set-AzBootstrapAzureInfra** (private): Creates RG, managed identity, assigns RBAC, sets up federated creds.
- **Set-AzBootstrapGitHubEnvironments** (private): Creates environments, sets secrets, policies, branch protection. Accepts explicit Owner/Repo parameters.
- **Grant-RBACRole** (private): Assigns a role to a principal at the RG scope.
- **Ensure-GhCli** (private): Ensures GitHub CLI is available (downloads if needed).
- **Get-AzGitRepositoryInfo** (private): Gets repo info from explicit parameters, git, or Codespaces env.
- **Invoke-AzGhCommand** (private): Runs a GitHub CLI command.
- **New-AzResourceGroup**, **New-AzManagedIdentity**, **New-AzFederatedCredential**: Atomic Azure resource operations.
- **New-AzGitHubEnvironment**, **Set-AzGitHubEnvironmentSecrets**, **Set-AzGitHubEnvironmentPolicy**, **New-AzGitHubBranchRuleset**: Atomic GitHub repo operations.

---

## Update Considerations

- **Always update or add Pester tests for new/changed logic.**
- **Update documentation (README.md, DESIGN.md) if workflows, parameters, or architecture change.**
- **If adding support for new cloud providers or repo hosts, keep logic modular and avoid hard-coding provider-specific details.**
- **If adding new environment policies or secrets, ensure they are parameterized and documented.**
- **If changing RBAC or security logic, review for least-privilege and idempotency.**
- **If updating CLI dependencies (az, gh), ensure compatibility and update Ensure-GhCli if needed.**
- **If adding interactive features, consider keeping them in a wrapper script, not the core module.**

---

## Useful Context for LLMs

- The workflow is: create new repo from template → clone new repo → bootstrap infra and GitHub settings.
- All private GitHub functions should accept explicit Owner/Repo parameters for testability and correctness.
- Tests should mock `gh repo create` as well as `gh secret`, `gh api`, etc.
- This module should remain cross-platform where possible.
- The main use case is IaC project bootstrap for Azure + GitHub, but extensibility is a goal.
- All external calls to Azure or GitHub should be mockable for tests.
- The module is intended for both human and automated (CI/CD) use.
- If in doubt, prefer explicit, parameterized, and testable code.

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
