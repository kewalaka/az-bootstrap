function Test-AzCli {
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$SubscriptionId
    )
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        return $false
    }

    Write-Host "[az-bootstrap] Checking Azure CLI authentication status..."
    $accountInfo = az account show --query "{id:id, name:name, tenantId:tenantId}" --output json | ConvertFrom-Json
    Write-Host "[az-bootstrap] Currently connected to subscription: '$($accountInfo.name | Out-String -NoNewline)'"
    if (-not $accountInfo) {
        Write-Warning "Azure CLI is not authenticated. Please run 'az login' and authenticate before running this command."
        return $false
    }
    if ($TenantId -and $accountInfo.tenantId -ne $TenantId) {
        Write-Warning "Azure CLI is not authenticated to the requested tenant ($TenantId). Current tenant: $($accountInfo.tenantId)"
        Write-Host "Please run 'az login' and make sure you authenticate to the tenant specified via ARM_TENANT_ID or the -TenantId parameter."
        return $false
    }
    if ($SubscriptionId -and $accountInfo.id -ne $SubscriptionId) {
        Write-Warning "Azure CLI is not set to the requested subscription ($SubscriptionId). Current subscription: $($accountInfo.id)"
        Write-Host "Please run 'az login' and make sure you authenticate to the subscription specified via ARM_SUBSCRIPTION_ID or the -SubscriptionId parameter."
        return $false
    }
    Write-Host "[az-bootstrap] Azure Subscription: $($accountInfo.name) ($($accountInfo.id)) in Tenant: $($accountInfo.tenantId)"
 
    return $true
}