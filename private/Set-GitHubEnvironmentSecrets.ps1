function Set-GitHubEnvironmentSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [Parameter(Mandatory)][string]$Secrets
    )
    foreach ($key in $secrets.Keys) {
        $cmd = @("gh", "secret", "set", $key, "--env", $EnvironmentName, "-b", $secrets[$key])
        & $cmd[0] $cmd[1..($cmd.Count - 1)] | Out-Null
        Write-Host "✔ Secret '$key' set for environment '$EnvironmentName'."
    }
}
