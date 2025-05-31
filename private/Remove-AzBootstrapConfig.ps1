function Remove-AzBootstrapConfig {
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
            return $false
        }
    }
    
    # Check if config file exists
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Configuration file not found at '$ConfigPath' (may have already been removed)."
        return $true
    }
    
    try {
        # Read existing config
        $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        
        # Check if environments property exists
        if (-not $configContent.environments) {
            Write-Warning "No environments found in configuration file."
            return $true
        }
        
        # Check if the environment exists and remove it
        if ($configContent.environments.PSObject.Properties.Name -contains $EnvironmentName) {
            $configContent.environments.PSObject.Properties.Remove($EnvironmentName)
            Write-Verbose "Removed environment '$EnvironmentName' from config file."
        } else {
            Write-Warning "Environment '$EnvironmentName' not found in configuration file (may have already been removed)."
            return $true
        }
        
        # If no environments remain, we can optionally keep the file structure or remove it
        # For now, we'll keep the file structure
        
        # Write updated config back to file
        $configContent | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
        
        Write-BootstrapLog "Removed environment '$EnvironmentName' from configuration file." -Level Success
        return $true
    }
    catch {
        Write-Error "Failed to remove environment from configuration file '$ConfigPath': $_"
        return $false
    }
}