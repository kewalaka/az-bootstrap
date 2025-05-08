function New-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName
    )
    $cmd = @("gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName")
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
    Write-Host "Environment '$EnvironmentName' created/updated in $Owner/$Repo."
}
