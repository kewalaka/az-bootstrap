function New-GitHubBranchRuleset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter()]
        [string]$RulesetName = "main",
        [Parameter()]
        [string]$TargetPattern = "main",
        [Parameter()]
        [int]$RequiredApprovals = 1,
        [Parameter()]
        [bool]$DismissStaleReviews = $true,
        [Parameter()]
        [bool]$RequireCodeOwnerReview = $false,
        [Parameter()]
        [bool]$RequireLastPushApproval = $true,
        [Parameter()]
        [bool]$RequireThreadResolution = $false,
        [Parameter()]
        [string[]]$AllowedMergeMethods = @("squash"),
        [Parameter()]
        [bool]$EnableCopilotReview = $true
    )
    # Check if a ruleset with this name already exists
    $getRulesetsCmd = @(
        "gh", "api", "-X", "GET", "/repos/$Owner/$Repo/rulesets",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2022-11-28"
    )
    try {
        $existingRulesets = Invoke-GitHubCliCommand -Command $getRulesetsCmd | ConvertFrom-Json
        $existingRuleset = $existingRulesets | Where-Object { $_.name -eq $RulesetName }
        $rulesetExists = $null -ne $existingRuleset
    }
    catch {
        Write-Warning "Failed to query existing rulesets: $_"
        $rulesetExists = $false
    }
    # Prepare the ruleset payload
    $rulesetPayload = @{
        name           = $RulesetName
        target         = "branch"
        target_pattern = $TargetPattern
        enforcement    = "active"
        rules          = @(
            @{
                type       = "pull_request"
                parameters = @{
                    dismiss_stale_reviews_on_push         = $DismissStaleReviews
                    require_code_owner_review             = $RequireCodeOwnerReview
                    require_last_push_approval            = $RequireLastPushApproval
                    required_approving_review_count       = $RequiredApprovals
                    required_review_thread_resolution     = $RequireThreadResolution
                    allowed_merge_methods                 = $AllowedMergeMethods
                    automatic_copilot_code_review_enabled = $EnableCopilotReview
                }
            }
        )
        conditions     = @{
            ref_name = @{
                include = @("~DEFAULT_BRANCH")
                exclude = @()
            }
        }
    } | ConvertTo-Json -Depth 10
    $tempFile = New-TemporaryFile
    Set-Content -Path $tempFile -Value $rulesetPayload -Encoding UTF8
    if ($rulesetExists) {
        $rulesetCmd = @(
            "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/rulesets/$($existingRuleset.id)",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "--input", $tempFile
        )
        $actionMessage = "updated"
    }
    else {
        $rulesetCmd = @(
            "gh", "api", "-X", "POST", "/repos/$Owner/$Repo/rulesets",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "--input", $tempFile
        )
        $actionMessage = "created"
    }
    try {
        Invoke-GitHubCliCommand -Command $rulesetCmd | Out-Null
        Write-BootstrapLog "Ruleset '$RulesetName' $actionMessage and enforced on the default branch." -Level Success -NoPrefix
        return $true
    }
    catch {
        Write-Warning "Failed to $actionMessage the ruleset '$RulesetName': $_"
        return $false
    }
    finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue | Out-Null
    }
}
