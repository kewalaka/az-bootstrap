function Get-ManagedIdentityName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseName,
        
        [Parameter(Mandatory)]
        [string]$Environment,
        
        [Parameter(Mandatory)]
        [ValidateSet('plan', 'apply')]
        [string]$Type,
        
        [string]$Override
    )
    
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return $Override
    }
    
    return "mi-$BaseName-$Environment-$Type"
}
