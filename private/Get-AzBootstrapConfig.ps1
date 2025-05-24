function Get-AzBootstrapConfig {
    [CmdletBinding()]
    param()
    
    # Determine config file path based on OS
    $configFileName = ".az-bootstrap.jsonc"
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        $configPath = Join-Path $env:USERPROFILE $configFileName
    } else {
        $configPath = Join-Path $env:HOME $configFileName
    }
    
    # Return empty hashtable if config file doesn't exist
    if (-not (Test-Path $configPath)) {
        Write-Verbose "Global config file not found at '$configPath'. Using defaults."
        return @{}
    }
    
    try {
        Write-Verbose "Loading global config from '$configPath'"
        $jsonContent = Get-Content -Path $configPath -Raw
        
        # Remove JSONC comments (basic implementation)
        # This removes // style comments and /* */ style comments
        $jsonContent = $jsonContent -replace '(?m)^\s*//.*$', ''
        $jsonContent = $jsonContent -replace '(?s)/\*.*?\*/', ''
        
        $config = $jsonContent | ConvertFrom-Json -AsHashtable
        return $config
    }
    catch {
        Write-Warning "Failed to load global config file '$configPath': $_. Using defaults."
        return @{}
    }
}