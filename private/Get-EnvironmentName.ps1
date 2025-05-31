function Get-EnvironmentName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory)]
        [ValidateSet('plan', 'apply')]
        [string]$Type,
        
        [string]$Override
    )
    
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return $Override
    }
    
    return "${EnvironmentName}-iac-${Type}"
}
