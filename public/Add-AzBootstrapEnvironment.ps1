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

  # Retrieve Azure context (Subscription ID and Tenant ID)
  # This ensures we have the necessary Azure context, regardless of how this function is called.
  if (-not $ArmTenantId -or -not $ArmSubscriptionId) {
    $azContext = Get-AzCliContext # This function handles checks and throws on failure
    $ArmSubscriptionId = $azContext.SubscriptionId
    $ArmTenantId = $azContext.TenantId
  }

  $RepoInfo = Get-GitHubRepositoryInfo -OverrideOwner $GitHubOwner -OverrideRepo $GitHubRepo
  if (-not $RepoInfo) {
    throw "Could not determine GitHub repository information. Ensure you are in a git repository or provide -Owner and -Repo parameters."
  }

  $actualPlanEnvName = if (-not [string]::IsNullOrWhiteSpace($PlanEnvNameOverride)) {
    $PlanEnvNameOverride
  }
  else {
    "${EnvironmentName}-iac-plan"
  }
  $actualApplyEnvName = if (-not [string]::IsNullOrWhiteSpace($ApplyEnvNameOverride)) {
    $ApplyEnvNameOverride
  }
  else {
    "${EnvironmentName}-iac-apply"
  }

  $ApplyManagedIdentityName = if (-not [string]::IsNullOrWhiteSpace($ApplyManagedIdentityName)) {
    $ApplyManagedIdentityName
  }
  else {
    $PlanManagedIdentityName.Replace("-plan", "-apply")
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
      "TFSTATE_RESOURCE_GROUP_NAME"  = $ResourceGroupName
      "TFSTATE_STORAGE_ACCOUNT_NAME" = $TerraformStateStorageAccountName
    }
  }

  Write-Host "[az-bootstrap] Configuring GitHub environment '$actualPlanEnvName'..."
  New-GitHubEnvironment -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualPlanEnvName

  $secrets["ARM_CLIENT_ID"] = $infraDetails.PlanManagedIdentityClientId

  Set-GitHubEnvironmentSecrets -Owner $RepoInfo.Owner `
    -Repo $RepoInfo.Repo `
    -EnvironmentName $actualPlanEnvName `
    -Secrets $secrets

  Write-Host "[az-bootstrap] Configuring GitHub environment '$actualApplyEnvName'..."
  New-GitHubEnvironment -Owner $RepoInfo.Owner -Repo $RepoInfo.Repo -EnvironmentName $actualApplyEnvName

  $secrets["ARM_CLIENT_ID"] = $infraDetails.ApplyManagedIdentityClientId

  Set-GitHubEnvironmentSecrets -Owner $RepoInfo.Owner `
    -Repo $RepoInfo.Repo `
    -EnvironmentName $actualApplyEnvName `
    -Secrets $secrets


  # add reviewers to the apply environment
  Set-GitHubEnvironmentPolicy -Owner $RepoInfo.Owner `
    -Repo $RepoInfo.Repo `
    -EnvironmentName $actualApplyEnvName `
    -UserReviewers $ApplyEnvironmentUserReviewers `
    -TeamReviewers $ApplyEnvironmentTeamReviewers `
    -AddOwnerAsReviewer $AddOwnerAsReviewer 

  Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
  Write-Host "[az-bootstrap] GitHub environments '$actualPlanEnvName' and '$actualApplyEnvName' configured successfully."

  
  $environmentConfig = [PSCustomObject]@{
    EnvironmentName              = $EnvironmentName
    ResourceGroupName            = $ResourceGroupName
    Location                     = $Location
    PlanManagedIdentityName      = $PlanManagedIdentityName
    ApplyManagedIdentityName     = $ApplyManagedIdentityName
    PlanGitHubEnvironmentName    = $actualPlanEnvName
    ApplyGitHubEnvironmentName   = $actualApplyEnvName
    PlanManagedIdentityClientId  = $infraDetails.PlanManagedIdentityClientId
    ApplyManagedIdentityClientId = $infraDetails.ApplyManagedIdentityClientId
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

