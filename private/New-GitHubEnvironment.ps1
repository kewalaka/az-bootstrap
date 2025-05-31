function New-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName
    )
    Invoke-GitHubApiCommand -Method "PUT" -Endpoint "/repos/$Owner/$Repo/environments/$EnvironmentName" | Out-Null
    Write-Bootstraplog "Environment '$EnvironmentName' created/updated in $Owner/$Repo." -Level Success
}
