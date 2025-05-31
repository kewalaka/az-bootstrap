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
    # Get default from global config if available, otherwise use hardcoded default
    $config = Get-AzBootstrapConfig
    $defaultTemplateRepo = if ($config.ContainsKey('defaultRepository') -and -not [string]::IsNullOrWhiteSpace($config.defaultRepository)) {
        $config.defaultRepository
    } else {
        "kewalaka/terraform-azure-starter-template"
    }
    
    $templateRepoUrl = Read-Host "Enter Template Repository URL [$defaultTemplateRepo]"
    if ([string]::IsNullOrWhiteSpace($templateRepoUrl)) {
        $templateRepoUrl = $defaultTemplateRepo
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
    $defaults.TargetRepoName = $targetRepoName

    # Default storage account name
    $randomPadding = Get-Random -Minimum 100 -Maximum 999
    $defaultStorageAccountName = "st$($defaults.TargetRepoName)$initialEnv$randomPadding" -replace '[^a-z0-9]', ''
    if ($defaultStorageAccountName.Length -gt 24) { $defaultStorageAccountName = $defaultStorageAccountName.Substring(0, 24) }
    $defaults.TerraformStateStorageAccountName = $defaultStorageAccountName

    # Azure Location
    $location = Read-Host "Enter Azure Location [$($defaults.Location)]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = $defaults.Location
    }
    $defaults.Location = $location

    # Resource Group
    $defaultResourceGroupName = if (-not [string]::IsNullOrWhiteSpace($defaults.ResourceGroupName)) {
        $defaults.ResourceGroupName
    }
    else {
        "rg-$($defaults.TargetRepoName)-$initialEnv"
    }    
    $resourceGroupName = Read-Host "Enter Resource Group Name [$defaultResourceGroupName]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaultResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Managed identities.  Use the helper to generate a name unless overriden
    # Prompt for Plan Managed Identity Name with default fallback
    $defaultPlanMi = Get-ManagedIdentityName -BaseName $defaults.TargetRepoName -Environment $initialEnv -Type 'plan' -Override $defaults.PlanManagedIdentityName
    $inputPlanMi = Read-Host "Enter Plan Managed Identity Name [$($defaultPlanMi)]"
    if ([string]::IsNullOrWhiteSpace($inputPlanMi)) {
        $planManagedIdentityName = $defaultPlanMi
    }
    else {
        $planManagedIdentityName = $inputPlanMi
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Prompt for Apply Managed Identity Name with default fallback
    $defaultApplyMi = Get-ManagedIdentityName -BaseName $defaults.TargetRepoName -Environment $initialEnv -Type 'apply' -Override $defaults.ApplyManagedIdentityName
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