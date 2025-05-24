function Set-AzBootstrapConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$TemplateAlias,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Value
    )

    # Get the existing configuration using private function
    $config = & "$PSScriptRoot/../private/Get-AzBootstrapConfig.ps1"

    # Determine config file path based on OS
    $configFileName = ".az-bootstrap.jsonc"
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        $configPath = Join-Path $env:USERPROFILE $configFileName
    } else {
        $configPath = Join-Path $env:HOME $configFileName
    }

    # If config is empty, initialize it
    if (-not $config) {
        $config = @{
            templateAliases = @{}
        }
    }

    # If templateAliases section doesn't exist, create it
    if (-not $config.ContainsKey('templateAliases')) {
        $config.templateAliases = @{}
    }

    # Add or update the template alias
    $config.templateAliases[$TemplateAlias] = $Value

    try {
        # Convert to JSON with proper formatting
        $jsonContent = $config | ConvertTo-Json -Depth 10

        # Create directory if it doesn't exist
        $configDir = Split-Path -Path $configPath -Parent
        if (-not (Test-Path $configDir) -and $configDir) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }

        # Save configuration to file
        $jsonContent | Set-Content -Path $configPath -Encoding UTF8
        Write-Host "[az-bootstrap] Successfully updated configuration at $configPath"
        Write-Host "[az-bootstrap] Added/updated template alias: $TemplateAlias -> $Value"
    }
    catch {
        Write-Error "[az-bootstrap] Failed to save configuration to $configPath`: $_"
    }
}