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

        [string]$ArmTenantId = $env:ARM_TENANT_ID,
        [string]$ArmSubscriptionId = $env:ARM_SUBSCRIPTION_ID,
        # Removed ArmClientId parameter, it's derived from the created Managed Identity
        [string]$Owner, # Optional, defaults to current user/org
        [string[]]$ApplyEnvironmentReviewers = @(), # Default reviewers for the Apply environment (empty array = no reviewers)
        [string]$ProtectedBranchName = "main", # Default branch to protect
        [bool]$RequirePR = $true, # Default: Require PR for protected branch
        [int]$RequiredReviewers = 1 # Default: Required reviewers for protected branch
    )

    if (Test-Path $TargetDirectory) {
        throw "Target directory '$TargetDirectory' already exists. Please specify a new directory."
    }

    # Create new repo from template
    $ownerArg = if ($Owner) { "--owner $Owner" } else { "" }
    Write-Host "[az-bootstrap] Creating new GitHub repo '$TargetRepoName' from template: $TemplateRepoUrl"
    $cmd = "gh repo create $TargetRepoName --template $TemplateRepoUrl --public $ownerArg --confirm"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create new GitHub repository from template."
    }

    # Clone the new repo
    Write-Host "[az-bootstrap] Cloning new repo to $TargetDirectory"
    $repoUrl = if ($Owner) { "https://github.com/$Owner/$TargetRepoName.git" } else { "https://github.com/$TargetRepoName.git" }
    git clone $repoUrl $TargetDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone new repository from $repoUrl."
    }

    # Change to the target directory for subsequent operations
    Push-Location $TargetDirectory
    try {
        # Get repo info once
        $repoInfo = Get-AzGitRepositoryInfo -OverrideOwner $Owner
        if (-not $repoInfo) {
            throw "Could not determine repository information from git remote or overrides."
        }
        $actualOwner = $repoInfo.Owner
        $actualRepo = $repoInfo.Repo

        # Azure infra setup - capture the managed identity object
        $mi = Set-AzBootstrapAzureInfra -ResourceGroupName $ResourceGroupName -Location $Location -ManagedIdentityName $ManagedIdentityName -PlanEnvName $PlanEnvName -ApplyEnvName $ApplyEnvName -Owner $actualOwner -Repo $actualRepo
        if (-not $mi -or -not $mi.clientId) {
            throw "Failed to create managed identity or retrieve its client ID."
        }

        # GitHub environment setup - pass necessary info
        Set-AzBootstrapGitHubEnvironments -PlanEnvName $PlanEnvName `
                                          -ApplyEnvName $ApplyEnvName `
                                          -ArmTenantId $ArmTenantId `
                                          -ArmSubscriptionId $ArmSubscriptionId `
                                          -ArmClientId $mi.clientId ` # Pass the actual client ID
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
