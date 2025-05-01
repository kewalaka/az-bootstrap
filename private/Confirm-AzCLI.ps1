function Confirm-AzCli {
  [CmdletBinding()]
  param(
      [string]$TenantId,
      [string]$SubscriptionId
  )
  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
      throw "'az' CLI is not installed or not available in PATH. Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
  }

  Write-Host "[az-bootstrap] Checking Azure CLI authentication status..."
  $accountInfo = az account show --query "{id:id, name:name, tenantId:tenantId}" --output json | ConvertFrom-Json
  if (-not $accountInfo) {
      throw "Azure CLI is not authenticated. Please run 'az login' and authenticate before running this command."
  }
  if ($TenantId -and $accountInfo.tenantId -ne $TenantId) {
      throw "Azure CLI is not authenticated to the required tenant ($TenantId). Current tenant: $($accountInfo.tenantId)"
  }
  if ($SubscriptionId -and $accountInfo.id -ne $SubscriptionId) {
      throw "Azure CLI is not set to the required subscription ($SubscriptionId). Current subscription: $($accountInfo.id)"
  }
  Write-Host "[az-bootstrap] Azure Subscription: $($accountInfo.name) ($($accountInfo.id)) in Tenant: $($accountInfo.tenantId)"
 
  return $true
}