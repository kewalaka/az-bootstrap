function Remove-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    
    try {
        # Delete the GitHub environment using GitHub API
        Invoke-GitHubApiCommand -Method "DELETE" -Endpoint "/repos/$Owner/$Repo/environments/$EnvironmentName" | Out-Null
        Write-BootstrapLog "GitHub environment '$EnvironmentName' removed from $Owner/$Repo." -Level Success
    }
    catch {
        # Handle case where environment doesn't exist (404) gracefully
        if ($_.Exception.Message -match "404" -or $_.Exception.Message -match "Not Found") {
            Write-Warning "GitHub environment '$EnvironmentName' not found in $Owner/$Repo (may have already been removed)."
        } else {
            Write-Error "Failed to remove GitHub environment '$EnvironmentName' from $Owner/$Repo`: $_"
            throw
        }
    }
}