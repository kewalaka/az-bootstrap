function Remove-AzBootstrapEnvironment {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubOwner,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubRepo,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force  # Skip confirmation prompts
    )
    
    # Check if we're in interactive mode (no environment name provided)
    $isInteractiveMode = [string]::IsNullOrWhiteSpace($EnvironmentName)
    
    if ($isInteractiveMode) {
        Write-Verbose "[az-bootstrap] No environment name provided, entering interactive mode."
        
        # Get repository info to find the config file
        $RepoInfo = Get-GitHubRepositoryInfo -OverrideOwner $GitHubOwner -OverrideRepo $GitHubRepo
        if (-not $RepoInfo) {
            throw "Could not determine GitHub repository information. Ensure you are in a git repository or provide -GitHubOwner and -GitHubRepo parameters."
        }
        
        # Find the config file
        if (-not $ConfigPath) {
            $repoPath = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and $repoPath) {
                $ConfigPath = Join-Path $repoPath ".azbootstrap.jsonc"
            } else {
                throw "Could not determine repository root path and no ConfigPath provided."
            }
        }
        
        # Check if config file exists
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at '$ConfigPath'. No environments to remove."
        }
        
        # Read config and show available environments
        try {
            $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            if (-not $configContent.environments -or $configContent.environments.PSObject.Properties.Count -eq 0) {
                throw "No environments found in configuration file."
            }
            
            $availableEnvironments = $configContent.environments.PSObject.Properties.Name
            Write-Host "Available environments:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $availableEnvironments.Count; $i++) {
                Write-Host "  $($i + 1). $($availableEnvironments[$i])" -ForegroundColor Yellow
            }
            
            # Get user selection
            do {
                $selection = Read-Host "Select environment to remove (number or name)"
                if ($selection -match '^\d+$') {
                    $index = [int]$selection - 1
                    if ($index -ge 0 -and $index -lt $availableEnvironments.Count) {
                        $EnvironmentName = $availableEnvironments[$index]
                        break
                    }
                } elseif ($availableEnvironments -contains $selection) {
                    $EnvironmentName = $selection
                    break
                }
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            } while ($true)
        }
        catch {
            throw "Failed to read configuration file: $_"
        }
    }
    
    # Validate required parameters
    if ([string]::IsNullOrWhiteSpace($EnvironmentName)) {
        throw "EnvironmentName is required."
    }
    
    # Get environment configuration
    $envConfig = Get-AzBootstrapEnvironmentConfig -EnvironmentName $EnvironmentName -ConfigPath $ConfigPath
    if (-not $envConfig) {
        throw "Environment '$EnvironmentName' not found in configuration."
    }
    
    # Get repository info if not provided
    if (-not $GitHubOwner -or -not $GitHubRepo) {
        $RepoInfo = Get-GitHubRepositoryInfo -OverrideOwner $GitHubOwner -OverrideRepo $GitHubRepo
        if (-not $RepoInfo) {
            throw "Could not determine GitHub repository information. Ensure you are in a git repository or provide -GitHubOwner and -GitHubRepo parameters."
        }
        $GitHubOwner = $RepoInfo.Owner
        $GitHubRepo = $RepoInfo.Repo
    }
    
    # Display what will be removed
    Write-Host "`nThe following resources will be removed:" -ForegroundColor Yellow
    Write-Host "  Environment: $EnvironmentName" -ForegroundColor Cyan
    if ($envConfig.ResourceGroupName) {
        Write-Host "  Azure Resource Group: $($envConfig.ResourceGroupName)" -ForegroundColor Cyan
    }
    if ($envConfig.DeploymentStackName) {
        Write-Host "  Azure Deployment Stack: $($envConfig.DeploymentStackName)" -ForegroundColor Cyan
    }
    if ($envConfig.PlanGitHubEnvironmentName) {
        Write-Host "  GitHub Environment: $($envConfig.PlanGitHubEnvironmentName)" -ForegroundColor Cyan
    }
    if ($envConfig.ApplyGitHubEnvironmentName) {
        Write-Host "  GitHub Environment: $($envConfig.ApplyGitHubEnvironmentName)" -ForegroundColor Cyan
    }
    
    # Confirm deletion unless Force is specified
    if (-not $Force -and -not $PSCmdlet.ShouldProcess($EnvironmentName, "Remove environment and all associated resources")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "`nAre you sure you want to remove environment '$EnvironmentName' and all its resources? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    Write-BootstrapLog "Removing environment '$EnvironmentName'..."
    
    # Remove GitHub environments
    try {
        if ($envConfig.PlanGitHubEnvironmentName) {
            Write-BootstrapLog "Removing GitHub environment '$($envConfig.PlanGitHubEnvironmentName)'..."
            Remove-GitHubEnvironment -Owner $GitHubOwner -Repo $GitHubRepo -EnvironmentName $envConfig.PlanGitHubEnvironmentName
        }
        
        if ($envConfig.ApplyGitHubEnvironmentName) {
            Write-BootstrapLog "Removing GitHub environment '$($envConfig.ApplyGitHubEnvironmentName)'..."
            Remove-GitHubEnvironment -Owner $GitHubOwner -Repo $GitHubRepo -EnvironmentName $envConfig.ApplyGitHubEnvironmentName
        }
    }
    catch {
        Write-Warning "Failed to remove some GitHub environments: $_"
        # Continue with other cleanup operations
    }
    
    # Remove Azure deployment stack
    try {
        if ($envConfig.DeploymentStackName) {
            Write-BootstrapLog "Removing Azure deployment stack '$($envConfig.DeploymentStackName)'..."
            Remove-AzDeploymentStack -StackName $envConfig.DeploymentStackName
        } else {
            Write-Warning "No deployment stack name found in configuration. Azure resources may need to be cleaned up manually."
        }
    }
    catch {
        Write-Warning "Failed to remove Azure deployment stack: $_"
        # Continue with config cleanup
    }
    
    # Remove environment from configuration file
    try {
        $configRemoved = Remove-AzBootstrapConfig -EnvironmentName $EnvironmentName -ConfigPath $ConfigPath
        if (-not $configRemoved) {
            Write-Warning "Failed to remove environment from configuration file."
        }
    }
    catch {
        Write-Warning "Failed to update configuration file: $_"
    }
    
    Write-BootstrapLog "Environment '$EnvironmentName' removal completed." -Level Success
    Write-BootstrapLog "Note: Some resources may take a few minutes to be fully deleted from Azure." -Level Info
}

Export-ModuleMember -Function Remove-AzBootstrapEnvironment