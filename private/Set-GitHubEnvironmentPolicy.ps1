function Set-GitHubEnvironmentPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [string[]]$UserReviewers = @(),
        [string[]]$TeamReviewers = @(),
        [bool]$AddOwnerAsReviewer = $false
    )
    Write-Host "Setting deployment branch policy on environment '$EnvironmentName'..."
    $reviewerFlags = @()
    $userList = $UserReviewers
    if ($AddOwnerAsReviewer -and $Owner) {
        if ($userList -notcontains $Owner) {
            $userList += $Owner
        }
    }
    $reviewerFlags = Get-ReviewerFlags -UserReviewers $userList -TeamReviewers $TeamReviewers -Org $Owner
    $cmd = @(
        "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2022-11-28"
    ) + $reviewerFlags + @(
        "-F", "deployment_branch_policy[protected_branches]=true",
        "-F", "deployment_branch_policy[custom_branch_policies]=false"
    )
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
    Write-Host "Reviewers set for '$EnvironmentName'."
}


function Get-UserId {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )
    $user = gh api "/users/$UserName" | ConvertFrom-Json
    return $user.id
}
  
function Get-TeamId {
    param(
        [Parameter(Mandatory)]
        [string]$TeamName,
        [Parameter(Mandatory)]
        [string]$Org
    )
    $team = gh api "/orgs/$Org/teams/$TeamName" | ConvertFrom-Json
    return $team.id
}
  
function Get-ReviewerFlags {
    param(
        [string[]]$UserReviewers = @(),
        [string[]]$TeamReviewers = @(),
        [Parameter(Mandatory)]
        [string]$Org
    )
    $flags = @()
    foreach ($user in $UserReviewers) {
        $id = Get-UserId -UserName $user
        $flags += "-F"
        $flags += "reviewers[][type]=User"
        $flags += "-F"
        $flags += "reviewers[][id]=$id"
    }
    foreach ($team in $TeamReviewers) {
        $id = Get-TeamId -TeamName $team -Org $Org
        $flags += "-F"
        $flags += "reviewers[][type]=Team"
        $flags += "-F"
        $flags += "reviewers[][id]=$id"
    }
    return $flags
}