function Add-AzBootstrapConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$EnvironmentConfig,

        [Parameter(Mandatory = $false)]
        [switch]$ForceCreate
    )

    # Get the current date/time in ISO format
    $timestamp = Get-Date -Format "o"

    # Add timestamp to the environment configuration
    $EnvironmentConfig | Add-Member -NotePropertyName "Timestamp" -NotePropertyValue $timestamp -Force

    try {
        # Check if file exists
        if (Test-Path $ConfigPath) {
            # Read existing config
            $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            
            # Check if environments property exists
            if (-not $configContent.environments) {
                $configContent | Add-Member -NotePropertyName "environments" -NotePropertyValue ([ordered]@{}) -Force
            }
            
            # Add or update environment in config
            $envName = $EnvironmentConfig.EnvironmentName
            if ($configContent.environments.PSObject.Properties.Name -contains $envName) {
                # Update existing environment
                Write-Verbose "Updating existing environment '$envName' in config file."
                $configContent.environments.PSObject.Properties.Remove($envName)
            } else {
                # Add new environment
                Write-Verbose "Adding new environment '$envName' to config file."
            }
            
            # Convert to PSObject and add property
            $configContent.environments | Add-Member -NotePropertyName $envName -NotePropertyValue $EnvironmentConfig -Force
            
            # Write updated config back to file
            $configContent | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
            
            Write-Host "[az-bootstrap] Updated configuration file at $ConfigPath"
        } else {
            # File doesn't exist, create new config file with schema
            $newConfig = [PSCustomObject]@{
                schemaVersion = "1.0"
                environments  = [PSCustomObject]@{
                    $EnvironmentConfig.EnvironmentName = $EnvironmentConfig
                }
            }
            
            # Create directory if it doesn't exist
            $configDir = Split-Path -Path $ConfigPath -Parent
            if (-not (Test-Path $configDir) -and $configDir) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            }
            
            # Write to file
            $newConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
            
            Write-Host "[az-bootstrap] Created new configuration file at $ConfigPath"
        }
        
        return $true
    } catch {
        Write-Error "Failed to save configuration to $ConfigPath`: $_"
        return $false
    }
}