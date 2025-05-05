function Add-Environment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$Location,
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,
        [Parameter(Mandatory)]
        [string]$ArmTenantId,
        [Parameter(Mandatory)]
        [string]$ArmSubscriptionId,
        [string]$Owner,
        [string]$Repo,
        [string[]]$ApplyEnvironmentReviewers = @(),
        [switch]$SkipRepoConfiguration
    )

    # Get repo info if not provided
    if (-not $Owner -or -not $Repo) {
        $repoInfo = Get-AzGitRepositoryInfo -OverrideOwner $Owner -OverrideRepo $Repo
        $Owner = $repoInfo.Owner
        $Repo = $repoInfo.Repo
    }

    # 1. Create Azure infrastructure for this environment
    $mi = New-AzEnvironmentInfrastructure `
        -EnvironmentName $EnvironmentName `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -ManagedIdentityName $ManagedIdentityName `
        -PlanEnvName $planEnvName `
        -ApplyEnvName $applyEnvName `
        -Owner $Owner `
        -Repo $Repo        
      
    # 2. Configure GitHub environments (plan/apply) for this environment if requested
    if (-not $SkipRepoConfiguration) {
        $planEnvName = "${EnvironmentName}-plan"
        $applyEnvName = "${EnvironmentName}-apply"
      
        Set-GitHubEnvironmentConfig `
            -EnvironmentName $EnvironmentName `
            -PlanEnvName $planEnvName `
            -ApplyEnvName $applyEnvName `
            -ArmTenantId $ArmTenantId `
            -ArmSubscriptionId $ArmSubscriptionId `
            -ArmClientId $mi.clientId `
            -Owner $Owner `
            -Repo $Repo `
            -ApplyEnvironmentReviewers $ApplyEnvironmentReviewers
    }

    return [PSCustomObject]@{
        EnvironmentName  = $EnvironmentName
        ResourceGroup    = $ResourceGroupName
        ManagedIdentity  = $mi
        PlanEnvironment  = $planEnvName
        ApplyEnvironment = $applyEnvName
    }
}

