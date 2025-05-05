function Remove-AzEnvironmentInfrastructure {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName
  )
  
  az group delete --name $ResourceGroupName --yes
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete resource group '$ResourceGroupName'."
  }
}