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

  New-AzResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location

  $mi = New-AzManagedIdentity `
    -ManagedIdentityName $ManagedIdentityName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location
  
  if ($null -eq $mi.PrincipalId) {
    throw "Failed to create or locate existing managed identity: $ManagedIdentityName"
  }

  if ($mi.WasCreated) {
    Write-Host "[az-bootstrap] Waiting 20 seconds for managed identity propagation..."
    Start-Sleep -Seconds 20
  }

  Grant-AzRBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -PrincipalName $ManagedIdentityName -RoleDefinition "Contributor"
  Grant-AzRBACRole -ResourceGroupName $ResourceGroupName -PrincipalId $mi.principalId -PrincipalName $ManagedIdentityName -RoleDefinition "Role Based Access Control Administrator"

  # Set up federated credentials for both environments
  $params = @{
    ManagedIdentityName = $ManagedIdentityName
    ResourceGroupName   = $ResourceGroupName
    Owner               = $Owner
    Repo                = $Repo
  }
  # Call the correct private function
  New-AzFederatedCredential @params -GitHubEnvironmentName $PlanEnvName
  if ($PlanEnvName -ne $ApplyEnvName) {
    New-AzFederatedCredential @params -GitHubEnvironmentName $ApplyEnvName
  }

  # Return the managed identity object which includes the clientId
  return $mi
}

