function Resolve-TargetRepositoryInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetRepoName,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubOwner
    )
    
    # If TargetRepoName contains owner/repo format
    if ($TargetRepoName -match '^[^/]+/[^/]+$') {
        $parts = $TargetRepoName -split '/', 2
        $parsedOwner = $parts[0]
        $parsedRepo = $parts[1]
        
        # If GitHubOwner was also provided, we have a conflict
        if ($GitHubOwner -and $GitHubOwner -ne $parsedOwner) {
            throw "Conflicting owner specification: TargetRepoName contains '$parsedOwner' but GitHubOwner parameter is '$GitHubOwner'. Please specify the owner in only one place."
        }
        
        Write-Verbose "Parsed TargetRepoName '$TargetRepoName' as owner '$parsedOwner' and repo '$parsedRepo'"
        
        return [PSCustomObject]@{
            Owner = $parsedOwner
            Repo = $parsedRepo
            Source = "ParsedFromTarget"
        }
    }
    
    # TargetRepoName is just the repo name, use the provided GitHubOwner or detect it
    $actualOwner = $GitHubOwner
    if (-not $actualOwner) {
        # Try to get the current user/org from gh CLI
        $user = gh auth status --show-token 2>$null | Select-String 'Logged in to github.com account (.*) \(' | ForEach-Object { $_.Matches.Groups[1].Value }
        if ($user) { 
            $actualOwner = $user 
        } else { 
            throw "Could not determine GitHub owner. Please specify -GitHubOwner parameter or use 'owner/repo' format for TargetRepoName." 
        }
    }
    
    Write-Verbose "Using TargetRepoName '$TargetRepoName' with owner '$actualOwner'"
    
    return [PSCustomObject]@{
        Owner = $actualOwner
        Repo = $TargetRepoName
        Source = if ($GitHubOwner) { "ProvidedOwner" } else { "DetectedOwner" }
    }
}