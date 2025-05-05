function New-AzManagedIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$Location
    )
    Write-Host "[az-bootstrap] Creating managed identity '$ManagedIdentityName'..."
    $mi = az identity create --name $ManagedIdentityName --resource-group $ResourceGroupName --location $Location | ConvertFrom-Json
    if (-not $mi) { throw "Failed to create managed identity $ManagedIdentityName" }
    Write-Host "✔ Managed identity '$ManagedIdentityName' created."
    return $mi
}