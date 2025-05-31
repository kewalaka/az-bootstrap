function Test-GitHubRepositoryExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repo
    )
    

    $cmd = @(
        "gh", "repo", "view", "$Owner/$Repo", "--json", "name", "--jq", ".name"
    )

    try {
        $repoName = Invoke-GitHubCliCommand -Command $cmd 2>$null
        return $null -ne $repoName -and $repoName.Trim() -eq $Repo
    }
    catch {
        return $false
    }
}