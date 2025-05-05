function Set-GitHubEnvironmentSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [string]$ArmTenantId,
        [string]$ArmSubscriptionId,
        [string]$ArmClientId
    )
    if (-not $ArmTenantId -or -not $ArmSubscriptionId -or -not $ArmClientId) {
        Write-Warning "One or more ARM parameters are missing. Skipping secret configuration for '$EnvironmentName'."
        return
    }
    $secrets = @{
        "ARM_TENANT_ID"       = $ArmTenantId
        "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
        "ARM_CLIENT_ID"       = $ArmClientId
    }
    foreach ($key in $secrets.Keys) {
        $cmd = @("gh", "secret", "set", $key, "--env", $EnvironmentName, "-b", $secrets[$key])
        & $cmd[0] $cmd[1..($cmd.Count - 1)] | Out-Null
        Write-Host "✔ Secret '$key' set for environment '$EnvironmentName'."
    }
}
