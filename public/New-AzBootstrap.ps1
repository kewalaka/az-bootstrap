function New-AzBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateRepoUrl,

        [Parameter(Mandatory)]
        [string]$TargetRepoName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,

        # required but can optionally use environment variables
        [string]$ArmTenantId = $env:ARM_TENANT_ID,
        [string]$ArmSubscriptionId = $env:ARM_SUBSCRIPTION_ID,
        
        # optional
        [string]$Owner, # Optional, defaults to current user/org
        [string]$InitialEnvironmentName = "dev",
        [string]$PlanEnvName = "${InitialEnvironmentName}-iac-plan",
        [string]$ApplyEnvName = "${InitialEnvironmentName}-iac-apply",        

        [ValidateSet("public", "private", "internal")]
        [string]$Visibility = "public",

        [string]$TargetDirectory, # defaults to ".\$targetreponame"

        [string[]]$ApplyEnvironmentReviewers = @(), # Default reviewers for the Apply environment (empty array = no reviewers)

        [string]$ProtectedBranchName = "main", # Default branch to protect
        
        [bool]$RequirePR = $true, # Default: Require PR for protected branch
        
        [int]$RequiredReviewers = 0, # Default: Required reviewers for protected branch

        # add the branch ruleset defaults
        [string]$BranchRulesetName = "main", # Default branch ruleset name
        [string]$BranchTargetPattern = "main", # Default branch target pattern
        [int]$BranchRequiredApprovals = 1, # Default required approvals for branch ruleset
        [bool]$BranchDismissStaleReviews = $true, # Default: Dismiss stale reviews on push
        [bool]$BranchRequireCodeOwnerReview = $false, # Default: Require code owner review
        [bool]$BranchRequireLastPushApproval = $false, # Default: Require last push approval
        [bool]$BranchRequireThreadResolution = $false, # Default: Require thread resolution
        [string[]]$BranchAllowedMergeMethods = @("squash"), # Default allowed merge methods
        [bool]$BranchEnableCopilotReview = $true, # Default: Enable Copilot review

        [bool]$AddOwnerAsReviewer = $true # Default: Add owner as reviewer for the Apply environment
    )

    #region: check target directory
    if (-not $TargetDirectory -or [string]::IsNullOrWhiteSpace($TargetDirectory)) {
        $TargetDirectory = Join-Path -Path (Get-Location) -ChildPath $TargetRepoName
    }

    if (Test-Path $TargetDirectory) {
        throw "Target directory '$TargetDirectory' already exists. Please specify a new directory."
    }
    #endregion

    #region: check CLI tools
    Write-Host "[az-bootstrap] Checking GitHub CLI authentication status..."
    if (-not (Test-GitHubCLI)) {
        throw "GitHub CLI is not authenticated. Please run 'gh auth login' to authenticate."
    }

    Write-Host "[az-bootstrap] Checking Az CLI authentication status..."
    if (-not (Test-AzCli -TenantId $ArmTenantId -SubscriptionId $ArmSubscriptionId)) {
        throw "Az CLI is not authenticated. Please run 'az login' to authenticate."
    }
    #endregion

    # GitHub repo
    $ownerArg = if ($Owner) { "--owner $Owner" } else { "" }
    $visibilityArg = switch ($Visibility) {
        "private" { "--private" }
        "internal" { "--internal" }
        Default { "--public" }
    }
    Write-Host "[az-bootstrap] Creating new GitHub repo '$TargetRepoName' from template: $TemplateRepoUrl"
    $cmd = "gh repo create $TargetRepoName --template $TemplateRepoUrl $visibilityArg $ownerArg"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create new GitHub repository from template."
    }

    $actualOwner = if ($Owner) { $Owner } else {
        # Try to get the current user/org from gh CLI
        $user = gh auth status --show-token 2>$null | Select-String 'Logged in to github.com account (.*) \(' | ForEach-Object { $_.Matches.Groups[1].Value }
        if ($user) { $user } else { throw "Could not determine GitHub owner. Please specify -Owner." }
    }

    $repoUrl = "https://github.com/$actualOwner/$TargetRepoName.git"
    Write-Host "[az-bootstrap] Cloning new repo '$actualOwner/$TargetRepoName' to $TargetDirectory"
    git clone $repoUrl $TargetDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone new repository from $repoUrl."
    }

    Push-Location $TargetDirectory
    try {
        $repoInfo = Get-GitHubRepositoryInfo
        if (-not $repoInfo) {
            throw "Could not determine repository information from git remote or overrides."
        }

        New-GitHubBranchRuleset -Owner $repoInfo.Owner `
            -Repo $repoInfo.Repo `
            -RulesetName "main" `
            -TargetPattern $ProtectedBranchName `
            -RequiredApprovals $RequiredReviewers `
            -DismissStaleReviews $BranchDismissStaleReviews `
            -RequireCodeOwnerReview $BranchRequireCodeOwnerReview `
            -RequireLastPushApproval $BranchRequireLastPushApproval `
            -RequireThreadResolution $BranchRequireThreadResolution `
            -AllowedMergeMethods $BranchAllowedMergeMethods `
            -EnableCopilotReview $BranchEnableCopilotReview
   
        # GitHub environment setup      
        $DeploymentEnv = Add-Environment `
            -EnvironmentName $InitialEnvironmentName `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -ManagedIdentityName $ManagedIdentityName `
            -ArmTenantId $ArmTenantId `
            -ArmSubscriptionId $ArmSubscriptionId `
            -Owner $repoInfo.Owner `
            -Repo $repoInfo.Repo `
            -PlanEnvName $PlanEnvName `
            -ApplyEnvName $ApplyEnvName `
            -ApplyEnvironmentReviewers $ApplyEnvironmentReviewers `
            -ApplyEnvironmentTeamReviewers $ApplyEnvironmentTeamReviewers `
            -AddOwnerAsReviewer $AddOwnerAsReviewer
        
        Write-Host "[az-bootstrap] $($DeploymentEnv.EnvironmentName) environment created."
    }
    finally {
        Pop-Location
    }

    Write-Host "[az-bootstrap] Bootstrap complete. 🎉"
}

Export-ModuleMember -Function New-AzBootstrap
