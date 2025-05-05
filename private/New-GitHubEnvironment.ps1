function New-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [string]$ArmTenantId = $env:ARM_TENANT_ID,
        [string]$ArmSubscriptionId = $env:ARM_SUBSCRIPTION_ID,
        [string]$ArmClientId = $env:ARM_CLIENT_ID
    )
    $cmd = @("gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName")
    Invoke-GitHubCliCommand -Command $cmd | Out-Null
    Write-Host "✔ Environment '$EnvironmentName' created/updated in $Owner/$Repo."
    if ($ArmTenantId -and $ArmSubscriptionId -and $ArmClientId) {
        Set-GitHubEnvironmentSecrets -Owner $Owner -Repo $Repo -EnvironmentName $EnvironmentName \
            -ArmTenantId $ArmTenantId -ArmSubscriptionId $ArmSubscriptionId -ArmClientId $ArmClientId
    }
}
