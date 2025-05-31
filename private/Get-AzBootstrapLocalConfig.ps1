function Get-AzBootstrapLocalConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )
    
    # If no path provided, try to find it in the current repository
    if (-not $ConfigPath) {
        $repoPath = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $repoPath) {
            $ConfigPath = Join-Path $repoPath ".azbootstrap.jsonc"
        } else {
            Write-Verbose "Could not determine repository root path for local config."
            return $null
        }
    }
    
    # Return null if config file doesn't exist
    if (-not (Test-Path $ConfigPath)) {
        Write-Verbose "Local config file not found at '$ConfigPath'."
        return $null
    }
    
    try {
        Write-Verbose "Loading local config from '$ConfigPath'"
        $jsonContent = Get-Content -Path $ConfigPath -Raw
        
        # Remove JSONC comments (basic implementation)
        $jsonContent = $jsonContent -replace '(?m)^\s*//.*$', ''
        $jsonContent = $jsonContent -replace '(?s)/\*.*?\*/', ''
        
        $config = $jsonContent | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Warning "Failed to load local config file '$ConfigPath': $_."
        return $null
    }
}