function Add-AzBootstrapEnvironment {
  [CmdletBinding(ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$Location,
    [Parameter(Mandatory = $true)]
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

    [string]$TerraformStateStorageAccountName
  )
  # Validate required parameters
  # Validate required parameters
  if (-not $EnvironmentName -or -not $ResourceGroupName -or -not $Location -or -not $PlanManagedIdentityName) {
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

  # Check if the resource group already exists
  Write-BootstrapLog "Checking if Azure resource group '$ResourceGroupName' already exists..."
  if (Test-AzResourceGroupExists -ResourceGroupName $ResourceGroupName) {
    throw "Azure resource group '$ResourceGroupName' already exists. Please choose a different name."
  }

  # Save configuration to .azbootstrap.jsonc at the top level of the repository
  $environmentConfig = [PSCustomObject]@{
    EnvironmentName              = $EnvironmentName
    ResourceGroupName            = $ResourceGroupName
    DeploymentStackName          = $infraDetails.DeploymentStackName
    PlanGitHubEnvironmentName    = $actualPlanEnvName
    ApplyGitHubEnvironmentName   = $actualApplyEnvName
    TerraformStateStorageAccountName = $TerraformStateStorageAccountName
  }

  $repoPath = git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $repoPath) {
    $configPath = Join-Path $repoPath ".azbootstrap.jsonc"
    Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $environmentConfig
  } else {
    Write-Warning "Could not determine repository root path. Skipping writing configuration file."
  }  

  # do the deployment
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

  # Create/update environment and set secrets
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
  New-GitHubEnvironment -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualPlanEnvName
  foreach ($key in $secrets.Keys) {
    Set-GitHubEnvironmentSecrets -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualPlanEnvName -Secrets @{$key=$secrets[$key]} 
  }

  Write-Bootstraplog "Configuring GitHub environment '$actualApplyEnvName'..."
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

  return $environmentConfig
}

Export-ModuleMember -Function Add-AzBootstrapEnvironment

