function Set-GitHubEnvironmentSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [Parameter(Mandatory)][hashtable]$Secrets
    )
    foreach ($key in $Secrets.Keys) {
        $cmd = @("gh", "secret", "set", $key, "--env", $EnvironmentName, "-b", $Secrets[$key])
        Invoke-GitHubCliCommand -Command $cmd | Out-Null
        Write-Host "✔ Secret '$key' set for environment '$EnvironmentName'."
    }
}
