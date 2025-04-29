function New-AzFederatedCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$GitHubEnvironmentName,
        [Parameter(Mandatory)]
        [string]$Owner, # Added parameter
        [Parameter(Mandatory)]
        [string]$Repo # Added parameter
    )
    # Removed call to Get-AzGitRepositoryInfo

    # Construct subject using passed-in owner/repo
    $subject  = "repo:$Owner/$Repo:environment:$GitHubEnvironmentName"
    $issuer   = "https://token.actions.githubusercontent.com"
    $credName = "gh-oidc-$Owner-$Repo-$GitHubEnvironmentName"

    $credName = $credName.ToLower() -replace '\s+','-'
    $subject  = $subject.ToLower() -replace '\s+','-'
    $param = @{
        Name         = $credName
        IdentityName = $ManagedIdentityName
        ResourceGroupName = $ResourceGroupName
        Audience     = @('api://AzureADTokenExchange')
        Issuer       = $issuer
        Subject      = $subject
    }
    # Use Az CLI for federated credential creation
    $json = $param | ConvertTo-Json -Compress
    $cmd = @(
        "az", "identity federated-credential create",
        "--name", $credName,
        "--identity-name", $ManagedIdentityName,
        "--resource-group", $ResourceGroupName,
        "--issuer", $issuer,
        "--subject", $subject,
        "--audiences", "api://AzureADTokenExchange"
    )
    $joined = $cmd -join ' '
    Write-Host "[az-bootstrap] Creating federated credential: $joined"
    $result = & az identity federated-credential create --name $credName --identity-name $ManagedIdentityName --resource-group $ResourceGroupName --issuer $issuer --subject $subject --audiences api://AzureADTokenExchange
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create federated credential $credName"
    }
    Write-Host "✔ Federated credential '$credName' created."
}