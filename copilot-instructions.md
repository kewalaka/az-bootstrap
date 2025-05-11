# Copilot Instructions for az-bootstrap

## Purpose
- Automate Azure and GitHub environment setup for IaC projects using PowerShell.
- Bootstrap secure, OIDC-based deployment pipelines for new projects, starting from a template repo.
- Support ongoing environment management (add/remove dev, test, prod, etc.).

## Key Concepts
- Uses a subscription-scoped Bicep template to provision:
  - Resource Group
  - Two Managed Identities (plan/apply)
  - Federated credentials for GitHub OIDC
  - RBAC assignments (Contributor, RBAC Admin)
- Configures GitHub environments, secrets, and branch protection for the target repo.
- All Azure infra is provisioned via Bicep, not PowerShell imperative code.

## Design Principles
- Public functions orchestrate workflows; private functions do atomic tasks.
- All state is passed via parameters (no magic globals).
- Idempotent: handle 'already exists' gracefully.
- All logic is covered by Pester tests; external calls are mockable.
- Use approved PowerShell verbs for function names.

## Folder Structure
- `public/`: Exported entry points (e.g., Invoke-AzBootstrap, Add-AzBootstrapEnvironment)
- `private/`: Internal helpers (not exported)
- `templates/`: Bicep templates
- `tests/`: Pester tests

## Function Responsibilities
- **Invoke-AzBootstrap**: Orchestrates full bootstrap (repo, infra, branch protection, initial env)
- **Add-AzBootstrapEnvironment**: Adds a new environment (Azure infra + GitHub config)
- **Remove-AzBootstrapEnvironment**: Removes an environment
- **Install-GitHubCLI**: Ensures GitHub CLI is available
- **New-AzBicepDeployment**: Deploys Bicep template (infra, MI, RBAC, FIC)
- **New-GitHubEnvironment/Secrets/Policy**: GitHub env and policy management

## GitHub Environment Management
- Reviewer/team/secret params are optional; skipped if empty.
- Reviewer IDs are resolved automatically.
- Protected branches default to `main` but are customizable.

## Update Workflow
1. Update/add function in `public/` or `private/`.
2. Add/update Pester tests in `tests/`.
3. Update `az-bootstrap.psm1` if needed.
4. Update docs if interface or workflow changes.
5. Run all tests (`Invoke-Pester -Path ./tests`).
6. Commit with a clear message.

## LLM Guidance
- Prefer explicit, parameterized, and testable code.
- All external calls (az, gh, git) must be mockable.
- If in doubt, check DESIGN.md and README.md for context.
- Use PowerShell approved verbs for function names.

# End of Copilot Instructions
