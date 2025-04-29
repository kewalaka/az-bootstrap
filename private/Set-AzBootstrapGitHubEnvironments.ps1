function Set-AzBootstrapGitHubEnvironments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlanEnvName,
        [Parameter(Mandatory)]
        [string]$ApplyEnvName,
        [Parameter(Mandatory)]
        [string]$ArmTenantId,
        [Parameter(Mandatory)]
        [string]$ArmSubscriptionId,
        [Parameter(Mandatory)]
        [string]$ArmClientId, # Now receiving the correct client ID
        [Parameter(Mandatory)]
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo,
        # New parameters for customization
        [Parameter(Mandatory)]
        [string[]]$ApplyEnvironmentReviewers,
        [Parameter(Mandatory)]
        [string]$ProtectedBranchName,
        [Parameter(Mandatory)]
        [bool]$RequirePR,
        [Parameter(Mandatory)]
        [int]$RequiredReviewers
    )
    # Removed redundant Get-AzGitRepositoryInfo call, owner/repo are now passed in

    $secrets = @{
        "ARM_TENANT_ID"       = $ArmTenantId
        "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
        "ARM_CLIENT_ID"       = $ArmClientId # Use the passed-in client ID
    }

    foreach ($envName in @($PlanEnvName, $ApplyEnvName | Select-Object -Unique)) {
        # Create or update the environment
        New-AzGitHubEnvironment -Owner $Owner -Repo $Repo -EnvironmentName $envName
        # Set secrets
        Set-AzGitHubEnvironmentSecrets -Owner $Owner -Repo $Repo -EnvironmentName $envName -Secrets $secrets
    }

    # Set environment policy for APPLY environment (if different from PLAN)
    if ($ApplyEnvName -ne $PlanEnvName) {
        # Use the passed-in reviewers
        Set-AzGitHubEnvironmentPolicy -Owner $Owner -Repo $Repo -EnvironmentName $ApplyEnvName -ProtectedBranches @($ProtectedBranchName) -Reviewers $ApplyEnvironmentReviewers
    }
    else {
        Write-Host "[az-bootstrap] PLAN and APPLY environments are the same. Skipping APPLY-specific policy configuration."
    }

    # Set branch protection for the specified branch using passed-in settings
    New-AzGitHubBranchRuleset -Owner $Owner -Repo $Repo -Branch $ProtectedBranchName -RequirePR $RequirePR -RequiredReviewers $RequiredReviewers
}
