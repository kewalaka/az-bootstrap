function Test-AzResourceGroupExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    Write-Verbose "Testing if resource group '$ResourceGroupName' exists..."

    try {
        $null = az group show --name $ResourceGroupName 2>$null
        $exists = $LASTEXITCODE -eq 0
        Write-Verbose ("Resource group '{0}' {1}" -f $ResourceGroupName, $(if ($exists) { "exists" } else { "does not exist" }))
        return $exists
    }
    catch {
        Write-Bootstraplog "Failed to check if resource group '$ResourceGroupName' exists: $_" -Level Warning
        return $false
    }
}