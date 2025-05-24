function Test-StorageAccountName {
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
    $availability = Test-AzStorageAccountNameAvailability -StorageAccountName $StorageAccountName
    if (-not $availability.IsValid) {
        throw "Storage account name '$StorageAccountName' is not available: $($availability.Reason)"
    }

    return $true
}
