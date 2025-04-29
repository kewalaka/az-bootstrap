function Set-AzGitHubEnvironmentSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [Parameter(Mandatory)][hashtable]$Secrets
    )
    foreach ($key in $Secrets.Keys) {
        $cmd = @("gh", "secret", "set", $key, "--env", $EnvironmentName, "-b", $Secrets[$key])
        Invoke-AzGhCommand -Command $cmd | Out-Null
        Write-Host "✔ Secret '$key' set for environment '$EnvironmentName'."
    }
}
