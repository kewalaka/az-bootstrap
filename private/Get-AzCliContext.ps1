function Get-AzCliContext {
    [CmdletBinding()]
    param()

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is not installed or not found in PATH. Please install it and ensure it's accessible."
    }

    Write-Verbose "[az-bootstrap] Retrieving Azure CLI context (Subscription ID and Tenant ID)..."
    $accountInfoJson = az account show --query "{id:id, name:name, tenantId:tenantId, user:user.name}" --output json
    
    if ($LASTEXITCODE -ne 0 -or -not $accountInfoJson) {
        throw "Azure CLI is not authenticated or failed to retrieve account information. Please run 'az login' and ensure a default subscription is set."
    }
    
    $accountDetails = $accountInfoJson | ConvertFrom-Json -ErrorAction SilentlyContinue

    if (-not $accountDetails -or -not $accountDetails.id -or -not $accountDetails.tenantId) {
        throw "Could not parse valid subscription ID and tenant ID from Azure CLI. Output was: $accountInfoJson"
    }
 
    return [PSCustomObject]@{
        SubscriptionId = $accountDetails.id
        TenantId       = $accountDetails.tenantId
        UserName       = $accountDetails.user
        SubscriptionName = $accountDetails.name
    }
}