function Get-AzBootstrapEnvironmentConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )
    
    # If no config path is provided, try to find it in the current repository
    if (-not $ConfigPath) {
        $repoPath = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $repoPath) {
            $ConfigPath = Join-Path $repoPath ".azbootstrap.jsonc"
        } else {
            Write-Error "Could not determine repository root path and no ConfigPath provided."
            return $null
        }
    }
    
    # Check if config file exists
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found at '$ConfigPath'."
        return $null
    }
    
    try {
        # Read and parse the config file
        $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        
        # Check if environments property exists
        if (-not $configContent.environments) {
            Write-Error "No environments found in configuration file."
            return $null
        }
        
        # Check if the specific environment exists
        if (-not $configContent.environments.PSObject.Properties.Name -contains $EnvironmentName) {
            Write-Error "Environment '$EnvironmentName' not found in configuration file."
            return $null
        }
        
        return $configContent.environments.$EnvironmentName
    }
    catch {
        Write-Error "Failed to read configuration from '$ConfigPath': $_"
        return $null
    }
}