function Test-AzResourceGroupExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    $cmd = "az group show --name $ResourceGroupName --query name -o tsv 2>$null"
    
    try {
        $result = Invoke-Expression $cmd
        return $LASTEXITCODE -eq 0 -and ($null -ne $result) -and ($result.Trim() -eq $ResourceGroupName)
    }
    catch {
        return $false
    }
}