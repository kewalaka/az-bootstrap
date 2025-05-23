function Invoke-AzBootstrap {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        #
        # parameters that were previously required, but now optional to support interactive mode
        #
        [Parameter(Mandatory = $false)]
        [string]$TemplateRepoUrl,
        [Parameter(Mandatory = $false)]
        [string]$TargetRepoName,
        [Parameter(Mandatory = $false)]
        [string]$Location, 

        #
        # optional parameters
        #
        [string]$TargetDirectory, # if not specified, the repo will be cloned to ./$TargetRepoName
        [string]$InitialEnvironmentName = "dev",

        # github repo parameters
        [string]$GitHubOwner, # if not specified, the current user will be used
        [ValidateSet('private', 'public', 'internal')]
        [string]$GitHubVisibility,

        # azure parameters
        [string]$ResourceGroupName,
        [string]$PlanManagedIdentityName,
        [string]$ApplyManagedIdentityName,
 
        # github branch protection
        [string]$ProtectedBranchName = 'default-branch-protection',
        [int]$BranchRequiredApprovals = 1,
        [bool]$BranchDismissStaleReviews = $true,
        [bool]$BranchRequireCodeOwnerReview = $false,
        [bool]$BranchRequireLastPushApproval = $false,
        [bool]$BranchRequireThreadResolution = $true,
        [string[]]$BranchAllowedMergeMethods = @("squash"),
        [bool]$BranchEnableCopilotReview = $true,

        # deployment reviewers
        [string[]]$ApplyEnvironmentUserReviewers,
        [string[]]$ApplyEnvironmentTeamReviewers,
        [bool]$AddOwnerAsReviewer = $true,

        # optional storage account for terraform state
        [string]$TerraformStateStorageAccountName = ""
    )

    #region: check parameters
    # Check if we're in interactive mode (no required parameters provided)
    $isInteractiveMode = [string]::IsNullOrWhiteSpace($TemplateRepoUrl) -or 
                          [string]::IsNullOrWhiteSpace($TargetRepoName) -or 
                          [string]::IsNullOrWhiteSpace($Location)
    
    if ($isInteractiveMode) {
        Write-Verbose "[az-bootstrap] No required parameters provided, entering interactive mode."
        $interactiveParams = Start-AzBootstrapInteractiveMode
        
        if ($null -eq $interactiveParams) {
            # User cancelled in interactive mode
            return
        }
        
        # Apply interactive params to our current parameters
        $TemplateRepoUrl = $interactiveParams.TemplateRepoUrl
        $TargetRepoName = $interactiveParams.TargetRepoName
        $Location = $interactiveParams.Location
        
        # Only override these if they weren't specified in the command line
        if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
            $ResourceGroupName = $interactiveParams.ResourceGroupName
        }
        if ([string]::IsNullOrWhiteSpace($PlanManagedIdentityName)) {
            $PlanManagedIdentityName = $interactiveParams.PlanManagedIdentityName
        }
        if ([string]::IsNullOrWhiteSpace($ApplyManagedIdentityName)) {
            $ApplyManagedIdentityName = $interactiveParams.ApplyManagedIdentityName
        }
        if ([string]::IsNullOrWhiteSpace($TerraformStateStorageAccountName)) {
            $TerraformStateStorageAccountName = $interactiveParams.TerraformStateStorageAccountName
        }
    }
    
    # Validate required parameters are now present
    if (-not $TemplateRepoUrl -or [string]::IsNullOrWhiteSpace($TemplateRepoUrl)) {
        throw "Template repository URL is required."
    }
    if (-not $TargetRepoName -or [string]::IsNullOrWhiteSpace($TargetRepoName)) {
        throw "Target repository name is required."
    }
    if (-not $Location -or [string]::IsNullOrWhiteSpace($Location)) {
        throw "Location is required."
    }
    #endregion

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

    Write-Verbose "[az-bootstrap] Retrieving current Azure subscription and tenant details..."
    $azContext = Get-AzCliContext
    $currentArmSubscriptionId = $azContext.SubscriptionId
    $currentArmTenantId = $azContext.TenantId
    #endregion

    if (-not $currentArmSubscriptionId -or -not $currentArmTenantId) {
        throw "Failed to retrieve current Azure Subscription ID and Tenant ID. Ensure you are logged in with 'az login' and a default subscription is set."
    }
    Write-Host "[az-bootstrap] Using Azure Tenant: $currentArmTenantId, authenticated as: $($azContext.UserName | Out-String -NoNewline)"
    Write-Host "[az-bootstrap] Using Azure Subscription: $($azContext.SubscriptionName | Out-String -NoNewline), id: $currentArmSubscriptionId"
    #endregion

    # GitHub repo
    $ownerArg = if ($GitHubOwner) { "--owner $GitHubOwner" } else { "" }
    $visibilityArg = switch ($GitHubVisibility) {
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

    $actualOwner = if ($GitHubOwner) { $GitHubOwner } else {
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
        $RepoInfo = Get-GitHubRepositoryInfo -OverrideOwner $actualOwner -OverrideRepo $TargetRepoName
        if (-not $RepoInfo) {
            throw "Could not determine GitHub repository information. Ensure you are in a git repository or provide the -Owner parameter."
        }

        Write-Host "[az-bootstrap] Setting up branch protection for '$($RepoInfo.Owner)/$($RepoInfo.Repo)' on branch '$ProtectedBranchName'..."
        New-GitHubBranchRuleset -Owner $RepoInfo.Owner `
            -Repo $RepoInfo.Repo `
            -RulesetName "default-branch-protection" `
            -TargetPattern $ProtectedBranchName `
            -RequiredApprovals $BranchRequiredApprovals `
            -DismissStaleReviews $BranchDismissStaleReviews `
            -RequireCodeOwnerReview $BranchRequireCodeOwnerReview `
            -RequireLastPushApproval $BranchRequireLastPushApproval `
            -RequireThreadResolution $BranchRequireThreadResolution `
            -AllowedMergeMethods $BranchAllowedMergeMethods `
            -EnableCopilotReview $BranchEnableCopilotReview

        # Construct names for the initial environment
        $initialRgName = if (-not [string]::IsNullOrWhiteSpace($ResourceGroupName)) {
            $ResourceGroupName
        }
        else {
            "rg$InitialEnvironmentName"
        }
        
        $planMiName = if (-not [string]::IsNullOrWhiteSpace($PlanManagedIdentityName)) {
            $PlanManagedIdentityName
        }
        else {
            "mi$($RepoInfo.Repo)$InitialEnvironmentName-plan"
        }

        $applyMiName = if (-not [string]::IsNullOrWhiteSpace($ApplyManagedIdentityName)) {
            $ApplyManagedIdentityName
        }
        else {
            "mi$($RepoInfo.Repo)$InitialEnvironmentName-apply"
        }

        $initialPlanEnvName = "${InitialEnvironmentName}-iac-plan"
        $initialApplyEnvName = "${InitialEnvironmentName}-iac-apply"

        Write-Host "[az-bootstrap] Creating initial environment '$InitialEnvironmentName'..."
        $addEnvParams = @{
            EnvironmentName                  = $InitialEnvironmentName
            ResourceGroupName                = $initialRgName
            Location                         = $Location
            PlanManagedIdentityName          = $planMiName
            ApplyManagedIdentityName         = $applyMiName
            ArmTenantId                      = $currentArmTenantId
            ArmSubscriptionId                = $currentArmSubscriptionId
            GitHubOwner                      = $RepoInfo.Owner
            GitHubRepo                       = $RepoInfo.Repo
            PlanEnvName                      = $initialPlanEnvName
            ApplyEnvName                     = $initialApplyEnvName
            ApplyEnvironmentUserReviewers    = $ApplyEnvironmentUserReviewers
            ApplyEnvironmentTeamReviewers    = $ApplyEnvironmentTeamReviewers
            AddOwnerAsReviewer               = $AddOwnerAsReviewer
            TerraformStateStorageAccountName = $TerraformStateStorageAccountName
        }

        $DeploymentEnv = Add-AzBootstrapEnvironment @addEnvParams
    }
    catch {
        Write-Error "Failed to add initial environment '$InitialEnvironmentName': $_"
        throw
    }
    finally {
        Pop-Location
    }

    Write-Host "[az-bootstrap] Repository  : 'https://github.com/$($RepoInfo.Owner)/$($RepoInfo.Repo)'."
    Write-Host "[az-bootstrap] ...cloned to: '$($TargetDirectory)'."
    Write-Host "[az-bootstrap] Azure Bootstrap complete. 🎉"
}

Export-ModuleMember -Function Invoke-AzBootstrap
