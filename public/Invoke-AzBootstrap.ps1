function Invoke-AzBootstrap {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        #
        # These are mandatory, but may be specified by running Az-Bootstrap in "interactive mode" (without parameters).
        #
        [string]$TemplateRepoUrl,
        [string]$TargetRepoName,
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
        [string]$TerraformStateStorageAccountName = "",

        # skips the prompt that asks for confirmation before proceeding
        [switch]$SkipConfirmation
    )
    
    # Attempt to resolve template URL (handles aliases and GitHub shorthand)
    $TemplateRepoUrl = Resolve-TemplateRepoUrl -TemplateRepoUrl $TemplateRepoUrl
    
    # If location is not provided, try to get it from the config
    if (-not $Location -or [string]::IsNullOrWhiteSpace($Location)) {
        $config = Get-AzBootstrapConfig
        if ($config.ContainsKey('defaultLocation') -and -not [string]::IsNullOrWhiteSpace($config.defaultLocation)) {
            $Location = $config.defaultLocation
            Write-Verbose "Using default location '$Location' from config file."
        }
        else {
            $Location = "australiaeast"
            Write-Verbose "No location specified, using default '$Location'."
        }
    }

    #region:check parameters
    # Check if we're in interactive mode (not all required parameters have been provided)
    $isInteractiveMode = [string]::IsNullOrWhiteSpace($TemplateRepoUrl) -or 
                          [string]::IsNullOrWhiteSpace($TargetRepoName) -or 
                          [string]::IsNullOrWhiteSpace($Location)

    if ($isInteractiveMode) {
        Write-Verbose "[az-bootstrap] No required parameters provided, entering interactive mode."
        # Prepare defaults for interactive mode
        $defaults = @{ 
            InitialEnvironmentName            = $InitialEnvironmentName
            TemplateRepoUrl                   = $TemplateRepoUrl
            TargetRepoName                    = $TargetRepoName
            Location                          = $Location
            ResourceGroupName                 = $ResourceGroupName
            PlanManagedIdentityName           = $PlanManagedIdentityName
            ApplyManagedIdentityName          = $ApplyManagedIdentityName
            TerraformStateStorageAccountName  = $TerraformStateStorageAccountName
        }
        $interactiveParams = Start-AzBootstrapInteractiveMode -Defaults $defaults

        # Apply interactive params to our current parameters
        $TemplateRepoUrl = $interactiveParams.TemplateRepoUrl
        $TargetRepoName = $interactiveParams.TargetRepoName
        $Location = $interactiveParams.Location
        $ResourceGroupName = $interactiveParams.ResourceGroupName
        $PlanManagedIdentityName = $interactiveParams.PlanManagedIdentityName
        $ApplyManagedIdentityName = $interactiveParams.ApplyManagedIdentityName
        $TerraformStateStorageAccountName = $interactiveParams.TerraformStateStorageAccountName
    }
    else
    {
        # set up the defaults
        $ResourceGroupName = if (-not [string]::IsNullOrWhiteSpace($ResourceGroupName)) {
            $ResourceGroupName
        }
        else {
            "rg-$TargetRepoName-$InitialEnvironmentName"
        }

        $PlanManagedIdentityName = Get-ManagedIdentityName -BaseName $TargetRepoName -Environment $InitialEnvironmentName -Type 'plan' -Override $PlanManagedIdentityName
        $ApplyManagedIdentityName = Get-ManagedIdentityName -BaseName $TargetRepoName -Environment $InitialEnvironmentName -Type 'apply' -Override $ApplyManagedIdentityName

        $initialPlanEnvName = Get-EnvironmentName -EnvironmentName $InitialEnvironmentName -Type 'plan'
        $initialApplyEnvName = Get-EnvironmentName -EnvironmentName $InitialEnvironmentName -Type 'apply'

        # interactive mode checks this during user input
        if (-not [string]::IsNullOrWhiteSpace($TerraformStateStorageAccountName)) {
            Test-AzStorageAccountName -StorageAccountName $TerraformStateStorageAccountName
        }
    }

    # az boostrap expects an empty target directory
    if (-not $TargetDirectory -or [string]::IsNullOrWhiteSpace($TargetDirectory)) {
        $TargetDirectory = Join-Path -Path (Get-Location) -ChildPath $TargetRepoName
    }

    if (Test-Path $TargetDirectory) {
        throw "Target directory '$TargetDirectory' already exists. Please specify a new directory."
    }
    #endregion

    #region: check CLI tools
    Write-BootstrapLog "Checking GitHub CLI authentication status..."
    if (-not (Test-GitHubCLI)) {
        throw "GitHub CLI is not authenticated. Please run 'gh auth login' to authenticate."
    }

    Write-Verbose "[az-bootstrap] Retrieving current Azure subscription and tenant details..."
    $azContext = Get-AzCliContext
    $currentArmSubscriptionId = $azContext.SubscriptionId
    $currentArmTenantId = $azContext.TenantId

    if (-not $currentArmSubscriptionId -or -not $currentArmTenantId) {
        throw "Failed to retrieve current Azure Subscription ID and Tenant ID. Ensure you are logged in with 'az login' and a default subscription is set."
    }
    #endregion

    # GitHub repo
    $TemplateRepoUrl = Resolve-TemplateRepoUrl -TemplateRepoUrl $TemplateRepoUrl
    $ownerArg = if ($GitHubOwner) { "--owner $GitHubOwner" } else { "" }
    $visibilityArg = switch ($GitHubVisibility) {
        "private" { "--private" }
        "internal" { "--internal" }
        Default { "--public" }
    }
    
    # Determine the actual owner if not provided
    $actualOwner = if ($GitHubOwner) { $GitHubOwner } else {
        # Try to get the current user/org from gh CLI
        $user = gh auth status --show-token 2>$null | Select-String 'Logged in to github.com account (.*) \(' | ForEach-Object { $_.Matches.Groups[1].Value }
        if ($user) { $user } else { throw "Could not determine GitHub owner. Please specify -Owner." }
    }

    # Check if the resource group already exists
    Write-BootstrapLog "Checking if Azure resource group '$ResourceGroupName' already exists..."
    if (Test-AzResourceGroupExists -ResourceGroupName $ResourceGroupName) {
        throw "Azure resource group '$ResourceGroupName' already exists. Please choose a different name."
    }
    
    # Check if the GitHub repository already exists
    Write-BootstrapLog "Checking if GitHub repo '$actualOwner/$TargetRepoName' already exists..."
    if (Test-GitHubRepositoryExists -Owner $actualOwner -Repo $TargetRepoName) {
        throw "GitHub repository '$actualOwner/$TargetRepoName' already exists. Please choose a different name."
    }

    if (-not $SkipConfirmation) {
        Write-Host "`n--- Configuration Summary ---" -ForegroundColor Green
        Write-Host "Template Repository URL      : $TemplateRepoUrl"
        Write-Host "Target Repository            : $actualOwner/$TargetRepoName"
        Write-Host "Azure Subscription           : $($azContext.SubscriptionName) ($($azContext.SubscriptionId))"
        Write-Host "Azure Tenant ID              : $($azContext.TenantId)"
        Write-Host "Azure Location               : $Location"
        Write-Host "Resource Group Name          : $ResourceGroupName"
        Write-Host "Plan Managed Identity Name   : $PlanManagedIdentityName"
        Write-Host "Apply Managed Identity Name  : $ApplyManagedIdentityName"
        Write-Host "Terraform State Storage Name : $($TerraformStateStorageAccountName -eq '' ? 'Not required' : $TerraformStateStorageAccountName)"
        Write-Host "----------------------------`n" -ForegroundColor Green

        $confirm = Read-Host "Proceed with bootstrap? (y/N)"
        if ($confirm -notin 'y','Y') {
            Write-Host "Bootstrap operation cancelled." -ForegroundColor Yellow
            return
        }
    }    
    
    #
    # end checks - now we start making things
    #
    Write-BootstrapLog "Creating new GitHub repo '$TargetRepoName' from template: $TemplateRepoUrl"
    $cmd = "gh repo create $TargetRepoName --template $TemplateRepoUrl $visibilityArg $ownerArg"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create new GitHub repository from template."
    }

    $repoUrl = "https://github.com/$actualOwner/$TargetRepoName.git"
    Write-BootstrapLog "Cloning new repo '$actualOwner/$TargetRepoName' to $TargetDirectory"
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

        Write-BootstrapLog "Setting up branch protection for '$($RepoInfo.Owner)/$($RepoInfo.Repo)' on branch '$ProtectedBranchName'..."
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
        
        Write-BootstrapLog "Creating initial environment '$InitialEnvironmentName'..."
        $addEnvParams = @{
            EnvironmentName                  = $InitialEnvironmentName
            ResourceGroupName                = $ResourceGroupName
            Location                         = $Location
            PlanManagedIdentityName          = $PlanManagedIdentityName
            ApplyManagedIdentityName         = $ApplyManagedIdentityName
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

        # The configuration file is created by Add-AzBootstrapEnvironment if it can determine the repository path
    }
    catch {
        Write-Error "Failed to add initial environment '$InitialEnvironmentName': $_"
        throw
    }
    finally {
        Pop-Location
    }

    Write-BootstrapLog "Repository  : 'https://github.com/$($RepoInfo.Owner)/$($RepoInfo.Repo)'."
    Write-BootstrapLog "...cloned to: '$($TargetDirectory)'."
    Write-BootstrapLog "Azure Bootstrap complete. 🎉"
}

Export-ModuleMember -Function Invoke-AzBootstrap
