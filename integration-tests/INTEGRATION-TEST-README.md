# Az-Bootstrap Integration Test

This directory contains integration tests for the Az-Bootstrap module.

## End-to-End Integration Test

The `Invoke-IntegrationTest.ps1` script provides an end-to-end test of the Az-Bootstrap module.

### What it does

1. Imports the Az-Bootstrap module
2. Generates random resource names to avoid conflicts
3. Calls `Invoke-AzBootstrap` with the required parameters in non-interactive mode
4. Verifies the repository was created successfully
5. Provides cleanup functionality to remove all resources created during testing

### Running the test

#### Manual execution:

```powershell
# Run the test (creates resources)
./Invoke-IntegrationTest.ps1

# Clean up resources
./Invoke-IntegrationTest.ps1 -Cleanup
```

#### GitHub Action:

The test can also be run via GitHub Actions workflow using manual dispatch. This requires the following secrets to be set in the repository:

- `AZURE_CLIENT_ID` - Service Principal ID with permissions to create resources
- `AZURE_TENANT_ID` - Azure tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
- `GH_TOKEN` - GitHub token with permissions to create repositories

## Resources Created

The integration test creates the following resources:

1. A new GitHub repository based on the template
2. An Azure resource group with the pattern `rg-azb-test-{random-suffix}`
3. Azure managed identities for plan and apply operations
4. GitHub environments in the new repository

All resources are automatically cleaned up at the end of the test or can be manually cleaned up using the `-Cleanup` parameter.

## Requirements

- PowerShell 7.0 or higher
- Azure CLI
- GitHub CLI (authenticated)
- Az PowerShell module