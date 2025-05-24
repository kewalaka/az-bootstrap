function Get-AzBootstrapConfig {
    [CmdletBinding()]
    param()

    # Get the existing configuration using private function
    $config = & "$PSScriptRoot/../private/Get-AzBootstrapConfig.ps1"

    # Determine config file path based on OS
    $configFileName = ".az-bootstrap.jsonc"
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        $configPath = Join-Path $env:USERPROFILE $configFileName
    } else {
        $configPath = Join-Path $env:HOME $configFileName
    }

    # Display configuration file path
    Write-Host "[az-bootstrap] Configuration file path: $configPath"
    
    if (-not (Test-Path $configPath)) {
        Write-Host "[az-bootstrap] Configuration file does not exist. Use Set-AzBootstrapConfig to create it."
        return
    }

    # Display template aliases if available
    if ($config.ContainsKey('templateAliases') -and $config.templateAliases.Count -gt 0) {
        Write-Host "`n[az-bootstrap] Template Aliases:"
        foreach ($alias in $config.templateAliases.Keys | Sort-Object) {
            Write-Host "  $alias -> $($config.templateAliases[$alias])"
        }
    } else {
        Write-Host "`n[az-bootstrap] No template aliases configured."
    }

    # Display default location if available
    if ($config.ContainsKey('defaultLocation') -and -not [string]::IsNullOrWhiteSpace($config.defaultLocation)) {
        Write-Host "`n[az-bootstrap] Default Location: $($config.defaultLocation)"
    } else {
        Write-Host "`n[az-bootstrap] No default location configured."
    }
    
    # Return the config object for pipeline use
    return $config
}