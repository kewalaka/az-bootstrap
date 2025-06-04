function Test-AzStorageAccountName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName
    )

    # Validate format: lowercase alphanumeric, 3-24 characters
    if ($StorageAccountName -cnotmatch '^[a-z0-9]{3,24}$') {
        throw "Storage account name must be 3-24 lowercase alphanumeric characters."  
    }

    # Check availability via Azure CLI
    $azOutput = az storage account check-name --name $StorageAccountName --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Storage account name '$StorageAccountName' could not be validated. Azure CLI error: $azOutput"
    }

    try {
        $azResult = $azOutput | ConvertFrom-Json
    }
    catch {
        throw "Storage account name '$StorageAccountName' could not be validated. Failed to parse Azure CLI response: $azOutput"
    }

    if (-not $azResult.nameAvailable) {
        $reason = if ($azResult.message) { $azResult.message } else { "Unknown reason" }
        throw "Storage account name '$StorageAccountName' is not available: $reason"
    }

    return $true
}
