function Set-AzBootstrapAzureInfra {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$Location,
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,
        [Parameter(Mandatory)]
        [string]$PlanEnvName,
        [Parameter(Mandatory)]
        [string]$ApplyEnvName,
        [Parameter(Mandatory)]
        [string]$Owner, # Added parameter
        [Parameter(Mandatory)]
        [string]$Repo # Added parameter
    )
    # Create resource group
    Write-Host "[az-bootstrap] Creating resource group '$ResourceGroupName' in location '$Location'..."
    $rg = az group create --name $ResourceGroupName --location $Location | ConvertFrom-Json
    if (-not $rg) { throw "Failed to create resource group $ResourceGroupName" }
    Write-Host "✔ Resource group '$ResourceGroupName' created."

    # Create managed identity
    Write-Host "[az-bootstrap] Creating managed identity '$ManagedIdentityName'..."
    $mi = az identity create --name $ManagedIdentityName --resource-group $ResourceGroupName --location $Location | ConvertFrom-Json
    if (-not $mi) { throw "Failed to create managed identity $ManagedIdentityName" }
    Write-Host "✔ Managed identity '$ManagedIdentityName' created."

    # Assign RBAC roles: Contributor and User Access Administrator
    $contributorRole = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    $userAccessAdminRole = "e8e2caa3-9b4a-4a6a-9c7b-1bffb6b2c221"
    Grant-RBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -RoleDefinitionId $contributorRole
    Grant-RBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -RoleDefinitionId $userAccessAdminRole

    # Set up federated credentials for both environments
    $params = @{
        ManagedIdentityName = $ManagedIdentityName
        ResourceGroupName = $ResourceGroupName
        Owner             = $Owner # Pass owner
        Repo              = $Repo # Pass repo
    }
    # Call the correct private function
    New-AzFederatedCredential @params -GitHubEnvironmentName $PlanEnvName
    if ($PlanEnvName -ne $ApplyEnvName) {
        New-AzFederatedCredential @params -GitHubEnvironmentName $ApplyEnvName
    }

    # Return the managed identity object which includes the clientId
    return $mi
}
