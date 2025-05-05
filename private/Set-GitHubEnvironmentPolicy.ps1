function Set-GitHubEnvironmentPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [string[]]$UserReviewers = @(),
        [string[]]$TeamReviewers = @(),
        [string[]]$ProtectedBranches = @("main")
    )
    Write-Host "Setting deployment branch policy on environment '$EnvironmentName'..."
    $reviewerFlags = @()
    if ($UserReviewers) {
        foreach ($user in $UserReviewers) {
            $userId = gh api "/users/$user" | ConvertFrom-Json | Select-Object -ExpandProperty id
            $reviewerFlags += @{ type = "User"; id = $userId }
        }
    }
    if ($TeamReviewers) {
        foreach ($team in $TeamReviewers) {
            $teamId = gh api "/orgs/$Owner/teams/$team" | ConvertFrom-Json | Select-Object -ExpandProperty id
            $reviewerFlags += @{ type = "Team"; id = $teamId }
        }
    }
    $payload = @{
        protected_branches = $ProtectedBranches
    }
    if ($reviewerFlags.Count -gt 0) {
        $payload.reviewers = $reviewerFlags
    }
    $payloadJson = $payload | ConvertTo-Json -Depth 5
    $cmd = @(
        "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName/deployment-branch-policy",
        "-f", "payload=$payloadJson"
    )
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host "✔ Deployment branch policy set for '$EnvironmentName'."
}