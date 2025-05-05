function New-AzEnvironmentInfrastructure {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$EnvironmentName,
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory)]
    [string]$Location,
    [Parameter(Mandatory)]
    [string]$ManagedIdentityName,
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$PlanEnvName,
    [Parameter(Mandatory)][string]$ApplyEnvName    
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
  
  # Assign RBAC roles
  Grant-AzRBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -PrincipalName $ManagedIdentityName -RoleDefinition "Contributor"
  Grant-AzRBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -PrincipalName $ManagedIdentityName -RoleDefinition "Role Based Access Control Administrator"

  # Set up federated credentials for both environments
  $params = @{
    ManagedIdentityName = $ManagedIdentityName
    ResourceGroupName   = $ResourceGroupName
    Owner               = $Owner # Pass owner
    Repo                = $Repo # Pass repo
  }
  # Call the correct private function
  New-AzFederatedCredential @params -GitHubEnvironmentName $PlanEnvName
  if ($PlanEnvName -ne $ApplyEnvName) {
    New-AzFederatedCredential @params -GitHubEnvironmentName $ApplyEnvName
  }

  # Return the managed identity object which includes the clientId
  return $mi
}

