function Test-AzStorageAccountName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName
    )

    # Validate format: lowercase alphanumeric, 3-24 characters
    if ($StorageAccountName -notmatch '^[a-z0-9]{3,24}$') {
        throw "Storage account name must be 3-24 lowercase alphanumeric characters."  
    }

    # Check availability via Azure CLI
    $azResult = az storage account check-name --name $StorageAccountName --output json 2>$null | ConvertFrom-Json
    if (-not $azResult.nameAvailable) {
        throw "Storage account name '$StorageAccountName' is not available: $($azResult.message)"
    }

    return $true
}
