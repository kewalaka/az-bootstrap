function Test-AzStorageAccountNameAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName
    )

    # Check if name is empty
    if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason = "Storage account name cannot be empty."
        }
    }

    # Check length (must be between 3 and 24 characters)
    if ($StorageAccountName.Length -lt 3 -or $StorageAccountName.Length -gt 24) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason = "Storage account name must be between 3 and 24 characters long."
        }
    }

    # Check if contains only lowercase letters and numbers
    if ($StorageAccountName -match '[^a-z0-9]') {
        return [PSCustomObject]@{
            IsValid = $false
            Reason = "Storage account name can only contain lowercase letters and numbers."
        }
    }

    # Check availability using Azure CLI
    Write-Verbose "[az-bootstrap] Checking if storage account name '$StorageAccountName' is available..."
    $checkResult = az storage account check-name --name $StorageAccountName --query "{nameAvailable:nameAvailable, reason:reason}" --output json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[az-bootstrap] Failed to check storage account name availability."
        return [PSCustomObject]@{
            IsValid = $false
            Reason = "Failed to check storage account name availability. Make sure Azure CLI is authenticated."
        }
    }

    $availability = $checkResult | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $availability.nameAvailable) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason = "Storage account name '$StorageAccountName' is not available. Reason: $($availability.reason)"
        }
    }

    return [PSCustomObject]@{
        IsValid = $true
        Reason = "Storage account name is valid and available."
    }
}