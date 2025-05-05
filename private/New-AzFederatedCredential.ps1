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
    # Removed call to Get-GitHubRepositoryInfo

    # Construct subject using passed-in owner/repo
    $subject = "repo:$Owner/$Repo:environment:$GitHubEnvironmentName"
    $issuer = "https://token.actions.githubusercontent.com"
    $credName = "gh-oidc-$Owner-$Repo-$GitHubEnvironmentName"

    $credName = $credName.ToLower() -replace '\s+', '-'
    $subject = $subject.ToLower() -replace '\s+', '-'

    # Use Az CLI for federated credential creation
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
    Write-Verbose "[az-bootstrap] Creating federated credential: $joined"
    & az identity federated-credential create --name $credName --identity-name $ManagedIdentityName --resource-group $ResourceGroupName --issuer $issuer --subject $subject --audiences api://AzureADTokenExchange
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create federated credential $credName"
    }
    Write-Host "✔ Federated credential '$credName' created."
}