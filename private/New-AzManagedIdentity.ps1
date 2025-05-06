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
    $existing = az identity show --name $ManagedIdentityName --resource-group $ResourceGroupName 2>$null | ConvertFrom-Json
    if ($existing) {
        Write-Host "✔ Managed identity '$ManagedIdentityName' already exists."
        $existing | Add-Member -MemberType NoteProperty -Name WasCreated -Value $false
        return $existing
    }
    $mi = az identity create --name $ManagedIdentityName --resource-group $ResourceGroupName --location $Location | ConvertFrom-Json
    if (-not $mi) { throw "Failed to create managed identity $ManagedIdentityName" }
    Write-Host "✔ Managed identity '$ManagedIdentityName' created."
    $mi | Add-Member -MemberType NoteProperty -Name WasCreated -Value $true
    return $mi
}