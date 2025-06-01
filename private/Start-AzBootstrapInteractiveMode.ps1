function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$defaults
    )

    Write-Host "`n" -NoNewline
    Write-BootstrapLog "Interactive Mode - Enter required values or press Enter to accept defaults`n"

    # Determine initial environment from defaults
    $initialEnv = $defaults.InitialEnvironmentName

    # Prompt for template repo URL
    $templateRepoUrl = Read-Host "Enter Template Repository URL [kewalaka/terraform-azure-starter-template]"
    if ([string]::IsNullOrWhiteSpace($templateRepoUrl)) {
        $templateRepoUrl = "kewalaka/terraform-azure-starter-template"
    }
    $defaults.TemplateRepoUrl = $templateRepoUrl

    # Prompt for Target Repository Name
    do {
        $targetRepoName = Read-Host "Enter Target Repository Name [$($defaults.TargetRepoName)]"
        if ([string]::IsNullOrWhiteSpace($targetRepoName)) {
            $targetRepoName = $defaults.TargetRepoName
        }
        if ([string]::IsNullOrWhiteSpace($targetRepoName)) {
            Write-Host "Target Repository Name cannot be empty."
        } 
    } while ([string]::IsNullOrWhiteSpace($targetRepoName))
    
    # Parse the target repo name in case it contains owner/repo format
    # For interactive mode, we'll store the full input but use just the repo part for Azure resource naming
    $defaults.TargetRepoName = $targetRepoName
    $repoNameForResources = $targetRepoName
    if ($targetRepoName -match '^[^/]+/[^/]+$') {
        $parts = $targetRepoName -split '/', 2
        $repoNameForResources = $parts[1]
        Write-Host "Detected owner/repo format. Will use '$($parts[0])' as owner and '$($parts[1])' for resource naming."
    }

    # Default storage account name - use repo name only (not owner part)
    $randomPadding = Get-Random -Minimum 100 -Maximum 999
    $defaultStorageAccountName = "st$repoNameForResources$initialEnv$randomPadding" -replace '[^a-z0-9]', ''
    if ($defaultStorageAccountName.Length -gt 24) { $defaultStorageAccountName = $defaultStorageAccountName.Substring(0, 24) }
    $defaults.TerraformStateStorageAccountName = $defaultStorageAccountName

    # Azure Location
    $location = Read-Host "Enter Azure Location [$($defaults.Location)]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = $defaults.Location
    }
    $defaults.Location = $location

    # Resource Group - use repo name only (not owner part)
    $defaultResourceGroupName = if (-not [string]::IsNullOrWhiteSpace($defaults.ResourceGroupName)) {
        $defaults.ResourceGroupName
    }
    else {
        "rg-$repoNameForResources-$initialEnv"
    }
    $resourceGroupName = Read-Host "Enter Resource Group Name [$defaultResourceGroupName]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaultResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Managed identities.  Use the helper to generate a name unless overriden - use repo name only (not owner part)
    # Prompt for Plan Managed Identity Name with default fallback
    $defaultPlanMi = Get-ManagedIdentityName -BaseName $repoNameForResources -Environment $initialEnv -Type 'plan' -Override $defaults.PlanManagedIdentityName
    $inputPlanMi = Read-Host "Enter Plan Managed Identity Name [$($defaultPlanMi)]"
    if ([string]::IsNullOrWhiteSpace($inputPlanMi)) {
        $planManagedIdentityName = $defaultPlanMi
    }
    else {
        $planManagedIdentityName = $inputPlanMi
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Prompt for Apply Managed Identity Name with default fallback
    $defaultApplyMi = Get-ManagedIdentityName -BaseName $repoNameForResources -Environment $initialEnv -Type 'apply' -Override $defaults.ApplyManagedIdentityName
    $inputApplyMi = Read-Host "Enter Apply Managed Identity Name [$($defaultApplyMi)]"
    if ([string]::IsNullOrWhiteSpace($inputApplyMi)) {
        $applyManagedIdentityName = $defaultApplyMi
    }
    else {
        $applyManagedIdentityName = $inputApplyMi
    }
    $defaults.ApplyManagedIdentityName = $applyManagedIdentityName

    # Do you want a Terraform state storage account? (default yes)
    $useTerraformStorage = Read-Host "Would you like to create a Terraform State Storage Account? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($useTerraformStorage)) { $useTerraformStorage = 'y' }
    if ($useTerraformStorage -match '^[yY]$') {
        do {
            $storageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)]"
            if ([string]::IsNullOrWhiteSpace($storageAccountName)) {
                $storageAccountName = $defaults.TerraformStateStorageAccountName
            }
            Write-BootstrapLog "Checking if Storage Account '$storageAccountName' is valid and available..."
            $valid = Test-AzStorageAccountName -StorageAccountName $storageAccountName
        } while (-not $valid)
        $defaults.TerraformStateStorageAccountName = $storageAccountName
    }
    else {
        $defaults.TerraformStateStorageAccountName = $null
    }

    Write-Host "`n" -NoNewline

    return $defaults
}