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
        [string]$PlanEnvName = "${EnvironmentName}-iac-plan",
        [string]$ApplyEnvName = "${EnvironmentName}-iac-apply",
        [string[]]$ApplyEnvironmentReviewers = @(),
        [string[]]$ApplyEnvironmentTeamReviewers = @(),
        [bool]$AddOwnerAsReviewer = $true,
        [switch]$SkipRepoConfiguration
    )

    # Get repo info if not provided
    if (-not $Owner -or -not $Repo) {
        $repoInfo = Get-GitHubRepositoryInfo -OverrideOwner $Owner -OverrideRepo $Repo
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
    $secrets = @{
        "ARM_TENANT_ID"       = $ArmTenantId
        "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
        "ARM_CLIENT_ID"       = $($mi.clientId).Trim()
    }
        
    if (-not $SkipRepoConfiguration) {      
        foreach ($envName in @($planEnvName, $applyEnvName | Select-Object -Unique)) {
            New-GitHubEnvironment -Owner $Owner -Repo $Repo -EnvironmentName $envName
            Set-GitHubEnvironmentSecrets -Owner $Owner -Repo $Repo -EnvironmentName $envName -Secrets $secrets
        }
        
        if ($applyEnvName -ne $planEnvName -and ($ApplyEnvironmentReviewers.Count -gt 0 -or $ApplyEnvironmentTeamReviewers.Count -gt 0 -or $AddOwnerAsReviewer)) {
            Set-GitHubEnvironmentPolicy -Owner $Owner -Repo $Repo -EnvironmentName $applyEnvName `
                -UserReviewers $ApplyEnvironmentReviewers `
                -TeamReviewers $ApplyEnvironmentTeamReviewers `
                -AddOwnerAsReviewer $AddOwnerAsReviewer
        }
    }

    return [PSCustomObject]@{
        EnvironmentName  = $EnvironmentName
        ResourceGroup    = $ResourceGroupName
        ManagedIdentity  = $mi
        PlanEnvironment  = $planEnvName
        ApplyEnvironment = $applyEnvName
    }
}

