function Set-GitHubEnvironmentConfig {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$EnvironmentName,
    [Parameter(Mandatory)]
    [string]$PlanEnvName,
    [Parameter(Mandatory)]
    [string]$ApplyEnvName,
    [Parameter(Mandatory)]
    [string]$ArmTenantId,
    [Parameter(Mandatory)]
    [string]$ArmSubscriptionId,
    [Parameter(Mandatory)]
    [string]$ArmClientId,
    [Parameter(Mandatory)]
    [string]$Owner,
    [Parameter(Mandatory)]
    [string]$Repo,
    [string[]]$ApplyEnvironmentReviewers = @()
  )

  $secrets = @{
    "ARM_TENANT_ID"       = $ArmTenantId
    "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
    "ARM_CLIENT_ID"       = $ArmClientId
  }

  foreach ($envName in @($PlanEnvName, $ApplyEnvName | Select-Object -Unique)) {
    # Create or update the environment
    New-GitHubEnvironment -Owner $Owner -Repo $Repo -EnvironmentName $envName
    # Set secrets
    Set-GitHubEnvironmentSecrets -Owner $Owner -Repo $Repo -EnvironmentName $envName -Secrets $secrets
  }

  # Set environment policy for APPLY environment (if different from PLAN)
  if ($ApplyEnvName -ne $PlanEnvName -and $ApplyEnvironmentReviewers.Count -gt 0) {
    Set-GitHubEnvironmentPolicy -Owner $Owner -Repo $Repo -EnvironmentName $ApplyEnvName -ProtectedBranches @("main") -Reviewers $ApplyEnvironmentReviewers
  }
}

