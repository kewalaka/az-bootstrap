# Az-Bootstrap Integration Test

## Bicep integration test

`Test-BicepDeployment.ps1` exists to help test changes to the Bicep template used for deployment.

To use, populate the `.env` file (see `.env.example` for illustration).

* `Test-BicepDeployment.ps1 -whatif` will do a what-if deployment on the resources
* `Test-BicepDeployment.ps1 -deploy` will use a deployment stack to deploy resources in `/templates/environment-infra.bicep`.

The `.env` file is used to simulate the process of passing params from Az-Bootstrap,
designed to be similar to the logic in `/private/New-AzBicepDeployment.ps1`

TODO - be good to have this included as part of CI testing.

## End-to-End Integration Test

`Invoke-IntegrationTest.ps1` provides an end-to-end test of the Az-Bootstrap module. The test follows the workflow:

1. Creates a new repository from the template repository
2. Provisions Azure resources (resource group, managed identities, etc.)
3. Configures GitHub environments and secrets
4. Verifies that everything was created correctly
5. Cleans up all resources when finished

### What it does

1. Imports the Az-Bootstrap module
2. Generates random resource names with timestamps to avoid conflicts
3. Calls `Invoke-AzBootstrap` with the required parameters in non-interactive mode
4. Verifies the repository and Azure resources were created successfully
5. Provides cleanup functionality to remove all resources created during testing
6. Records timing information for performance analysis

### Running the test

#### Manual execution

```powershell
# Run the test (creates resources)
./Invoke-IntegrationTest.ps1

# Clean up resources
./Invoke-IntegrationTest.ps1 -Cleanup
```

#### GitHub Action

The test can be run via GitHub Actions workflow using manual dispatch. The workflow is defined in `.github/workflows/integration-test.yml` and requires the following secrets to be set in the repository:

* `AZURE_CLIENT_ID` - Service Principal ID with permissions to create resources
* `AZURE_TENANT_ID` - Azure tenant ID
* `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
* `GH_TOKEN` - GitHub token with permissions to create repositories

## Resources Created

The integration test creates the following resources:

1. A new GitHub repository based on the template: <https://github.com/kewalaka/terraform-azure-starter-template/>
2. An Azure resource group with random name
3. Azure managed identities for plan and apply operations
4. GitHub environments with appropriate federated credentials and secrets

All resources are automatically cleaned up at the end of the test or can be manually cleaned up using the `-Cleanup` parameter.

## State Management

The test creates a state file (`integration-test-state.json`) to track created resources for cleanup. This file is automatically created during the test and removed after successful cleanup.

## Requirements

* PowerShell 7.0 or higher
* Azure CLI authenticated
* GitHub CLI authenticated
* Az PowerShell module
