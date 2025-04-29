function Get-AzGitRepositoryInfo {
    [CmdletBinding()]
    param(
        [string]$OverrideOwner,
        [string]$OverrideRepo
    )
    if ($OverrideOwner -and $OverrideRepo) {
        return [PSCustomObject]@{
            RemoteUrl = "https://github.com/$OverrideOwner/$OverrideRepo"
            Owner = $OverrideOwner
            Repo = $OverrideRepo
            RemoteOriginLine = "origin https://github.com/$OverrideOwner/$OverrideRepo.git (fetch)"
            Source = "Override"
        }
    }
    # Try git remote -v first
    $remoteOutput = git remote -v 2>$null | Select-String 'origin.*\(fetch\)' | Select-Object -First 1
    if ($remoteOutput) {
        $parts = $remoteOutput -split '\s+'
        $remoteUrl = $parts[1]
        try {
            [uri]$uri = $remoteUrl
            $segments = $uri.AbsolutePath.Trim('/') -split '/'
            if ($segments.Length -ge 2) {
                $owner = $segments[0]
                $repo = ($segments[1] -replace '\.git$', '')
                return [PSCustomObject]@{
                    RemoteUrl = $remoteUrl
                    Owner = $owner
                    Repo = $repo
                    RemoteOriginLine = $remoteOutput
                    Source = "GitRemote"
                }
            }
        } catch {}
    }
    # Fallback: Codespaces env vars
    if ($env:GITHUB_SERVER_URL -eq "https://github.com" -and $env:GITHUB_REPOSITORY) {
        $repoPath = $env:GITHUB_REPOSITORY
        $segments = $repoPath -split '/'
        if ($segments.Length -ge 2) {
            $owner = $segments[0]
            $repo = $segments[1]
            $remoteUrl = "https://github.com/$owner/$repo"
            $syntheticRemoteOriginLine = "origin $remoteUrl (fetch)"
            return [PSCustomObject]@{
                RemoteUrl = $remoteUrl
                Owner = $owner
                Repo = $repo
                RemoteOriginLine = $syntheticRemoteOriginLine
                Source = "Codespaces"
            }
        }
    }
    return $null
}