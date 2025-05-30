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
    Write-Bootstraplog "Setting deployment branch policy on environment '$EnvironmentName'..."
    
    $userList = $UserReviewers
    if ($AddOwnerAsReviewer -and $Owner) {
        if ($userList -notcontains $Owner) {
            $userList += $Owner
        }
    }
    
    $reviewerFlags = Get-ReviewerFlags -UserReviewers $userList -TeamReviewers $TeamReviewers -Org $Owner
    $additionalArgs = $reviewerFlags + @(
        "-F", "deployment_branch_policy[protected_branches]=true",
        "-F", "deployment_branch_policy[custom_branch_policies]=false"
    )
    
    Invoke-GitHubApiCommand -Method "PUT" -Endpoint "/repos/$Owner/$Repo/environments/$EnvironmentName" -AdditionalArgs $additionalArgs | Out-Null
    Write-Bootstraplog "Reviewers set for '$EnvironmentName'." -Level Success
}


function Get-UserId {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )
    $user = Invoke-GitHubApiCommand -Method "GET" -Endpoint "/users/$UserName" | ConvertFrom-Json
    return $user.id
}
  
function Get-TeamId {
    param(
        [Parameter(Mandatory)]
        [string]$TeamName,
        [Parameter(Mandatory)]
        [string]$Org
    )
    $team = Invoke-GitHubApiCommand -Method "GET" -Endpoint "/orgs/$Org/teams/$TeamName" | ConvertFrom-Json
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