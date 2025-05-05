function Set-GitHubBranchProtection {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Owner,
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [string]$Branch,
    [Parameter(Mandatory)]
    [bool]$RequirePR,
    [Parameter(Mandatory)]
    [int]$RequiredReviewers
  )
  
  Write-Host "[az-bootstrap] Setting branch protection for '$Branch'"
  New-GitHubBranchRuleset -Owner $Owner -Repo $Repo `
    -Branch $Branch `
    -RequirePR $RequirePR `
    -RequiredReviewers $RequiredReviewers
}