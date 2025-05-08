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
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo
    )

    # use a format string because otherwise $Repo:environment would be interpreted as a variable
    $subject = ('repo:{0}/{1}:environment:{2}' -f $Owner, $Repo, $GitHubEnvironmentName)
    
    $issuer = "https://token.actions.githubusercontent.com"
    $credName = "ghactions-$Owner-$Repo-$GitHubEnvironmentName"

    $credName = $credName.ToLower()
    $subject = $subject.ToLower()

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
    Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
    Write-Host "Federated credential '$credName' created."
}