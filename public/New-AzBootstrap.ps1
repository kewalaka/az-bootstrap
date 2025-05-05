function New-AzBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateRepoUrl,

        [Parameter(Mandatory)]
        [string]$TargetRepoName,

        [Parameter(Mandatory)]
        [string]$PlanEnvName,

        [Parameter(Mandatory)]
        [string]$ApplyEnvName,

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

        [ValidateSet("public", "private", "internal")]
        [string]$Visibility = "public",

        [string]$TargetDirectory, # defaults to ".\$targetreponame"

        [string[]]$ApplyEnvironmentReviewers = @(), # Default reviewers for the Apply environment (empty array = no reviewers)

        [string]$ProtectedBranchName = "main", # Default branch to protect
        
        [bool]$RequirePR = $true, # Default: Require PR for protected branch
        
        [int]$RequiredReviewers = 1 # Default: Required reviewers for protected branch
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
        $repoInfo = Get-AzGitRepositoryInfo
        if (-not $repoInfo) {
            throw "Could not determine repository information from git remote or overrides."
        }

        Set-GitHubBranchProtection -Owner $repoInfo.Owner `
            -Repo $repoInfo.Repo `
            -Branch $ProtectedBranchName `
            -RequirePR $RequirePR `
            -RequiredReviewers $RequiredReviewers
   
        # GitHub environment setup - pass necessary info
        $devEnv = Add-Environment `
            -EnvironmentName "dev" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -ManagedIdentityName $ManagedIdentityName `
            -ArmTenantId $ArmTenantId `
            -ArmSubscriptionId $ArmSubscriptionId `
            -Owner $repoInfo.Owner `
            -Repo $repoInfo.Repo `
            -ApplyEnvironmentReviewers $ApplyEnvironmentReviewers
        
        Write-Host "[az-bootstrap] Dev environment created with Plan/Apply environments."
    }
    finally {
        Pop-Location
    }

    Write-Host "[az-bootstrap] Bootstrap complete."
}

Export-ModuleMember -Function New-AzBootstrap
