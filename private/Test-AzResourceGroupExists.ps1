function Test-AzResourceGroupExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    

    $cmd = "az group show --name $ResourceGroupName --query name -o tsv 2>$null"
    
    Write-Verbose "Testing if resource group '$ResourceGroupName' exists..."
    
    try {
        $result = Invoke-Expression $cmd
        $exists = $LASTEXITCODE -eq 0 -and ($null -ne $result) -and ($result.Trim() -eq $ResourceGroupName)
        
        if ($exists) {
            Write-Verbose "Resource group '$ResourceGroupName' exists"
        } else {
            Write-Verbose "Resource group '$ResourceGroupName' does not exist"
        }
        
        return $exists
    }
    catch {
        Write-BootstrapLog "Failed to check if resource group '$ResourceGroupName' exists: $_" -Level Warning
        return $false
    }
}