function New-AzGitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName
    )
    $cmd = @("gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName")
    Invoke-AzGhCommand -Command $cmd | Out-Null
    Write-Host "✔ Environment '$EnvironmentName' created/updated in $Owner/$Repo."
}
