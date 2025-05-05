function Set-GitHubEnvironmentPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [string[]]$ProtectedBranches = @("main"),
        [string[]]$Reviewers = @()
    )
    $payload = @{
        protected_branches = $ProtectedBranches
        reviewers          = $Reviewers
    } | ConvertTo-Json
    $cmd = @(
        "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName/deployment-branch-policy",
        "-f", "payload=$payload"
    )
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host "✔ Deployment branch policy set for '$EnvironmentName'."
}
