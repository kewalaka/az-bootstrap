function Add-AzBootstrapEnvironment {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,
    
    [string]$ResourceGroupName,
    [string]$Location,
    [string]$PlanManagedIdentityName, # Name for the primary/plan MI

    [string]$ApplyManagedIdentityName,

    [string]$GitHubOwner,

    [string]$GitHubRepo,

    [string]$PlanEnvNameOverride,

    [string]$ApplyEnvNameOverride,

    [string[]]$ApplyEnvironmentUserReviewers,

    [string[]]$ApplyEnvironmentTeamReviewers,

    [bool]$AddOwnerAsReviewer = $true,

    [string]$ArmTenantId,
    [string]$ArmSubscriptionId,

    [string]$TerraformStateStorageAccountName,

    # skips the prompt that asks for confirmation before proceeding
    [switch]$SkipConfirmation
  )
  # Read local configuration to get project defaults
  $localConfig = Get-AzBootstrapLocalConfig
  $projectDefaults = @{}
  
  if ($localConfig -and $localConfig.environments) {
    # Extract common project patterns from existing environments
    $existingEnvs = $localConfig.environments.PSObject.Properties
    if ($existingEnvs.Count -gt 0) {
      $firstEnv = $existingEnvs[0].Value
      
      # Try to derive project base name from resource group pattern
      if ($firstEnv.ResourceGroupName -match '^rg-(.+?)-[^-]+$') {
        $projectDefaults.ProjectBaseName = $matches[1]
      }
      
      # Use location from first environment as default
      if ($firstEnv.DeploymentStackName -match 'rg-(.+?)-(.+?)-\d+$') {
        # Extract location from deployment stack name pattern if available
        # This is a fallback; we'll also try to get it from global config
      }
    }
  }

  # Get global config for location default
  $globalConfig = Get-AzBootstrapConfig
  if (-not $Location -and $globalConfig.ContainsKey('defaultLocation') -and -not [string]::IsNullOrWhiteSpace($globalConfig.defaultLocation)) {
    $Location = $globalConfig.defaultLocation
    Write-Verbose "Using default location '$Location' from global config file."
  } elseif (-not $Location) {
    $Location = "australiaeast"
    Write-Verbose "No location specified, using default '$Location'."
  }

  # Check if we're in interactive mode (missing required parameters)
  $isInteractiveMode = [string]::IsNullOrWhiteSpace($ResourceGroupName) -or 
                       [string]::IsNullOrWhiteSpace($Location) -or 
                       [string]::IsNullOrWhiteSpace($PlanManagedIdentityName)

  if ($isInteractiveMode) {
    Write-Verbose "[az-bootstrap] Some required parameters not provided, entering interactive mode."
    
    # Prepare defaults for interactive mode
    $defaults = @{ 
      EnvironmentName                   = $EnvironmentName
      ResourceGroupName                 = $ResourceGroupName
      Location                          = $Location
      PlanManagedIdentityName           = $PlanManagedIdentityName
      ApplyManagedIdentityName          = $ApplyManagedIdentityName
      TerraformStateStorageAccountName  = $TerraformStateStorageAccountName
      ProjectBaseName                   = $projectDefaults.ProjectBaseName
    }
    
    $interactiveParams = Start-AzBootstrapEnvironmentInteractiveMode -Defaults $defaults

    # Apply interactive params to our current parameters
    $ResourceGroupName = $interactiveParams.ResourceGroupName
    $Location = $interactiveParams.Location
    $PlanManagedIdentityName = $interactiveParams.PlanManagedIdentityName
    $ApplyManagedIdentityName = $interactiveParams.ApplyManagedIdentityName
    $TerraformStateStorageAccountName = $interactiveParams.TerraformStateStorageAccountName
  } else {
    # Non-interactive mode: set up defaults for missing optional parameters
    if ([string]::IsNullOrWhiteSpace($ApplyManagedIdentityName)) {
      $ApplyManagedIdentityName = $PlanManagedIdentityName.Replace("-plan", "-apply")
    }
  }

  # Final validation of required parameters
  if ([string]::IsNullOrWhiteSpace($EnvironmentName) -or 
      [string]::IsNullOrWhiteSpace($ResourceGroupName) -or 
      [string]::IsNullOrWhiteSpace($Location) -or 
      [string]::IsNullOrWhiteSpace($PlanManagedIdentityName)) {
    throw "Parameters 'EnvironmentName', 'ResourceGroupName', 'Location', and 'PlanManagedIdentityName' are required"
  }

  # Retrieve Azure context (Subscription ID and Tenant ID) if not provided
  if (-not $ArmTenantId -or -not $ArmSubscriptionId) {
    $azContext = Get-AzCliContext # This function handles checks and throws on failure
    $ArmSubscriptionId = $azContext.SubscriptionId
    $ArmTenantId = $azContext.TenantId
  }

  # Check storage account name if provided
  if (-not [string]::IsNullOrWhiteSpace($TerraformStateStorageAccountName)) {
    $storageAccountValidation = Test-AzStorageAccountName -StorageAccountName $TerraformStateStorageAccountName
    if (-not $storageAccountValidation) {
      throw "A valid storage account is required."
    }
  }

  $RepoInfo = Get-GitHubRepositoryInfo -OverrideOwner $GitHubOwner -OverrideRepo $GitHubRepo
  if (-not $RepoInfo) {
    throw "Could not determine GitHub repository information. Ensure you are in a git repository or provide -Owner and -Repo parameters."
  }
  # Determine GitHub environment names
  $actualPlanEnvName = if (-not [string]::IsNullOrWhiteSpace($PlanEnvNameOverride)) { $PlanEnvNameOverride } else { "$EnvironmentName-iac-plan" }
  $actualApplyEnvName = if (-not [string]::IsNullOrWhiteSpace($ApplyEnvNameOverride)) { $ApplyEnvNameOverride } else { "$EnvironmentName-iac-apply" }

  $ApplyManagedIdentityName = if (-not [string]::IsNullOrWhiteSpace($ApplyManagedIdentityName)) {
    $ApplyManagedIdentityName
  }
  else {
    $PlanManagedIdentityName.Replace("-plan", "-apply")
  }

  # Confirmation summary before proceeding
  if (-not $SkipConfirmation) {
    Write-Host "`n--- Environment Configuration Summary ---" -ForegroundColor Green
    Write-Host "Environment Name             : $EnvironmentName"
    Write-Host "Azure Location               : $Location"
    Write-Host "Resource Group Name          : $ResourceGroupName"
    Write-Host "Plan Managed Identity Name   : $PlanManagedIdentityName"
    Write-Host "Apply Managed Identity Name  : $ApplyManagedIdentityName"
    Write-Host "Terraform State Storage Name : $($TerraformStateStorageAccountName -eq '' ? 'Not specified' : $TerraformStateStorageAccountName)"
    Write-Host "-------------------------------------------`n" -ForegroundColor Green

    $confirm = Read-Host "Proceed with environment creation? (y/N)"
    if ($confirm -notin 'y','Y') {
      Write-Host "Environment creation cancelled." -ForegroundColor Yellow
      return
    }
  }

  # Check if the resource group already exists
  Write-BootstrapLog "Checking if Azure resource group '$ResourceGroupName' already exists..."
  if (Test-AzResourceGroupExists -ResourceGroupName $ResourceGroupName) {
    throw "Azure resource group '$ResourceGroupName' already exists. Please choose a different name."
  }

  $infraDetails = New-AzBicepDeployment -EnvironmentName $EnvironmentName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -PlanManagedIdentityName $PlanManagedIdentityName `
    -ApplyManagedIdentityName $ApplyManagedIdentityName `
    -GitHubOwner $RepoInfo.Owner `
    -GitHubRepo $RepoInfo.Repo `
    -PlanEnvName $actualPlanEnvName `
    -ApplyEnvName $actualApplyEnvName `
    -ArmSubscriptionId $ArmSubscriptionId `
    -TerraformStateStorageAccountName $TerraformStateStorageAccountName

  if (-not $infraDetails) {
    throw "Failed to set up Azure infrastructure for environment '$EnvironmentName'."
  }

  $secrets = @{
    "ARM_TENANT_ID"       = $ArmTenantId
    "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
  }
  if (-not [string]::IsNullOrWhiteSpace($TerraformStateStorageAccountName)) {
    $secrets += @{
      "TF_STATE_RESOURCE_GROUP_NAME"  = $ResourceGroupName
      "TF_STATE_STORAGE_ACCOUNT_NAME" = $TerraformStateStorageAccountName
    }
  }  Write-Bootstraplog "Configuring GitHub environment '$actualPlanEnvName'..."
  # Create/update environment and set secrets
  New-GitHubEnvironment -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualPlanEnvName
  foreach ($key in $secrets.Keys) {
    Set-GitHubEnvironmentSecrets -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualPlanEnvName -Secrets @{$key=$secrets[$key]} 
  }

  Write-Bootstraplog "Configuring GitHub environment '$actualApplyEnvName'..."
  # Create/update environment and set secrets
  New-GitHubEnvironment -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualApplyEnvName
  foreach ($key in $secrets.Keys) {
    Set-GitHubEnvironmentSecrets -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualApplyEnvName -Secrets @{$key=$secrets[$key]} 
  }


  # add reviewers to the apply environment
  Set-GitHubEnvironmentPolicy -Owner $RepoInfo.Owner `
    -Repo $RepoInfo.Repo `
    -EnvironmentName $actualApplyEnvName `
    -UserReviewers $ApplyEnvironmentUserReviewers `
    -TeamReviewers $ApplyEnvironmentTeamReviewers `
    -AddOwnerAsReviewer $AddOwnerAsReviewer 

  Write-BootstrapLog "GitHub environments '$actualPlanEnvName' and '$actualApplyEnvName' configured successfully." -Level Success
  
  $environmentConfig = [PSCustomObject]@{
    EnvironmentName              = $EnvironmentName
    ResourceGroupName            = $ResourceGroupName
    DeploymentStackName          = $infraDetails.DeploymentStackName
    PlanGitHubEnvironmentName    = $actualPlanEnvName
    ApplyGitHubEnvironmentName   = $actualApplyEnvName
    TerraformStateStorageAccountName = $TerraformStateStorageAccountName
  }

  # Save configuration to .azbootstrap.jsonc if we can determine the repository path
  $repoPath = git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $repoPath) {
    $configPath = Join-Path $repoPath ".azbootstrap.jsonc"
    Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $environmentConfig
  } else {
    Write-Warning "Could not determine repository root path. Skipping writing configuration file."
  }

  return $environmentConfig
}

Export-ModuleMember -Function Add-AzBootstrapEnvironment

