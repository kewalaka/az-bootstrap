function Remove-AzBootstrapEnvironment {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$EnvironmentName,
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [string]$Owner,
    [string]$Repo,
    [switch]$SkipRepoConfiguration,
    [switch]$Force
  )

  # Get repo info if not provided
  if (-not $SkipRepoConfiguration -and (-not $Owner -or -not $Repo)) {
    $repoInfo = Get-GitHubRepositoryInfo -OverrideOwner $Owner -OverrideRepo $Repo
    $Owner = $repoInfo.Owner
    $Repo = $repoInfo.Repo
  }

  # 1. Remove GitHub environments if requested
  if (-not $SkipRepoConfiguration) {
    $planEnvName = "${EnvironmentName}-iac-plan"
    $applyEnvName = "${EnvironmentName}-iac-apply"
      
    if ($PSCmdlet.ShouldProcess("GitHub environment $planEnvName", "Remove")) {
      Remove-GitHubEnvironment -Owner $Owner -Repo $Repo -EnvironmentName $planEnvName
    }
      
    if ($applyEnvName -ne $planEnvName) {
      if ($PSCmdlet.ShouldProcess("GitHub environment $applyEnvName", "Remove")) {
        Remove-GitHubEnvironment -Owner $Owner -Repo $Repo -EnvironmentName $applyEnvName
      }
    }
  }

  # 2. Remove Azure infrastructure
  if ($PSCmdlet.ShouldProcess("Resource group $ResourceGroupName", "Remove")) {
    if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to delete the entire resource group '$ResourceGroupName'?", "Delete resource group")) {
      Remove-AzEnvironmentInfrastructure -ResourceGroupName $ResourceGroupName
    }
  }
}