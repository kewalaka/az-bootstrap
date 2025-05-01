function New-AzBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateRepoUrl,

        [Parameter(Mandatory)]
        [string]$TargetRepoName,

        [Parameter(Mandatory)]
        [string]$TargetDirectory,

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
    if (-not (Install-GitHubCLI)) {
        throw "'gh' CLI is not available and could not be installed. Please install GitHub CLI: https://cli.github.com/"
    }
    Write-Host "[az-bootstrap] Checking GitHub CLI authentication status..."
    gh auth status --hostname github.com | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Please run 'gh auth login' and authenticate before running this command."
    }

    if (-not (Ensure-GhCli)) {
        throw "'gh' CLI is not available and could not be installed. Please install GitHub CLI: https://cli.github.com/"
    }
    Write-Host "[az-bootstrap] Checking GitHub CLI authentication status..."
    gh auth status --hostname github.com | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Please run 'gh auth login' and authenticate before running this command."
    }
    #endregion

    # GitHub repo
    $ownerArg = if ($Owner) { "--owner $Owner" } else { "" }
    Write-Host "[az-bootstrap] Creating new GitHub repo '$TargetRepoName' from template: $TemplateRepoUrl"
    $cmd = "gh repo create $TargetRepoName --template $TemplateRepoUrl --public $ownerArg --confirm"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create new GitHub repository from template."
    }

    Write-Host "[az-bootstrap] Cloning new repo to $TargetDirectory"
    $repoUrl = if ($Owner) { "https://github.com/$Owner/$TargetRepoName.git" } else { "https://github.com/$TargetRepoName.git" }
    git clone $repoUrl $TargetDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone new repository from $repoUrl."
    }

    Push-Location $TargetDirectory
    try {
        $repoInfo = Get-AzGitRepositoryInfo -OverrideOwner $Owner
        if (-not $repoInfo) {
            throw "Could not determine repository information from git remote or overrides."
        }
        $actualOwner = $repoInfo.Owner
        $actualRepo = $repoInfo.Repo

        $mi = Set-AzBootstrapAzureInfra -ResourceGroupName $ResourceGroupName -Location $Location -ManagedIdentityName $ManagedIdentityName -PlanEnvName $PlanEnvName -ApplyEnvName $ApplyEnvName -Owner $actualOwner -Repo $actualRepo
        if (-not $mi -or -not $mi.clientId) {
            throw "Failed to create managed identity or retrieve its client ID."
        }

        # GitHub environment setup - pass necessary info
        Set-AzBootstrapGitHubEnvironments -PlanEnvName $PlanEnvName `
                                          -ApplyEnvName $ApplyEnvName `
                                          -ArmTenantId $ArmTenantId `
                                          -ArmSubscriptionId $ArmSubscriptionId `
                                          -ArmClientId $mi.clientId `
                                          -Owner $actualOwner `
                                          -Repo $actualRepo `
                                          -ApplyEnvironmentReviewers $ApplyEnvironmentReviewers `
                                          -ProtectedBranchName $ProtectedBranchName `
                                          -RequirePR $RequirePR `
                                          -RequiredReviewers $RequiredReviewers
    }
    finally {
        Pop-Location
    }

    Write-Host "[az-bootstrap] Bootstrap complete."
}

Export-ModuleMember -Function New-AzBootstrap
