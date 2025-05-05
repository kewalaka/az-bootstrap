function New-GitHubBranchRuleset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Branch,
        [bool]$RequirePR = $true,
        [int]$RequiredReviewers = 1
    )
    $payload = @{
        required_pull_request_reviews = @{
            required_approving_review_count = $RequiredReviewers
        }
        enforce_admins = $true
        required_status_checks = $null
        restrictions = $null
    } | ConvertTo-Json
    $cmd = @(
        "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/branches/$Branch/protection",
        "-f", "payload=$payload"
    )
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host "✔ Branch protection set for '$Branch'."
}
