function New-AzResourceGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$Location
    )
    Write-Host "[az-bootstrap] Creating resource group '$ResourceGroupName' in location '$Location'..."
    $rg = az group create --name $ResourceGroupName --location $Location | ConvertFrom-Json
    if (-not $rg) { throw "Failed to create resource group $ResourceGroupName" }
    Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
    Write-Host "Resource group '$ResourceGroupName' created."
    return $rg
}