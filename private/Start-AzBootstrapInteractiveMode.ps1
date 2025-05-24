function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$defaults
    )

    Write-Host "`n[az-bootstrap] Interactive Mode - Enter required values or press Enter to accept defaults`n" -ForegroundColor Cyan

    # Determine initial environment from defaults
    $initialEnv = $defaults.InitialEnvironmentName

    # Prompt for template repo URL - no default as this is unique per project
    $templateRepoUrl = Read-Host "Enter Template Repository URL"
    if ([string]::IsNullOrWhiteSpace($templateRepoUrl)) {
        Write-Host "Template Repository URL is required." -ForegroundColor Red
        $templateRepoUrl = Read-Host "Enter Template Repository URL"
        if ([string]::IsNullOrWhiteSpace($templateRepoUrl)) {
            throw "Template Repository URL is required to proceed."
        }
    }
    $defaults.TemplateRepoUrl = $templateRepoUrl

    # Prompt for Target Repository Name
    $targetRepoName = Read-Host "Enter Target Repository Name [$($defaults.TargetRepoName)]"
    if ([string]::IsNullOrWhiteSpace($targetRepoName)) {
        $targetRepoName = $defaults.TargetRepoName
    }
    $defaults.TargetRepoName = $targetRepoName

    # Default storage account name
    $randomPadding = Get-Random -Minimum 100 -Maximum 999
    $storageDefault = "st$($defaults.TargetRepoName)$initialEnv$randomPadding" -replace '[^a-z0-9]', ''
    if ($storageDefault.Length -gt 24) { $storageDefault = $storageDefault.Substring(0,24) }
    $defaults.TerraformStateStorageAccountName = $storageDefault

    # Azure Location
    $location = Read-Host "Enter Azure Location [$($defaults.Location)]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = $defaults.Location
    }
    $defaults.Location = $location

    # Resource Group
    $resourceGroupName = Read-Host "Enter Resource Group Name [$($defaults.ResourceGroupName)]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaults.ResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Managed identities.  Use the helper to generate a name unless overriden
    # Prompt for Plan Managed Identity Name with default fallback
    $defaultPlanMi = Get-ManagedIdentityName -BaseName $defaults.TargetRepoName -Environment $initialEnv -Type 'plan' -Override $defaults.PlanManagedIdentityName
    $inputPlanMi = Read-Host "Enter Plan Managed Identity Name [$($defaultPlanMi)]"
    if ([string]::IsNullOrWhiteSpace($inputPlanMi)) {
        $planManagedIdentityName = $defaultPlanMi
    } else {
        $planManagedIdentityName = $inputPlanMi
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Prompt for Apply Managed Identity Name with default fallback
    $defaultApplyMi = Get-ManagedIdentityName -BaseName $defaults.TargetRepoName -Environment $initialEnv -Type 'apply' -Override $defaults.ApplyManagedIdentityName
    $inputApplyMi = Read-Host "Enter Apply Managed Identity Name [$($defaultApplyMi)]"
    if ([string]::IsNullOrWhiteSpace($inputApplyMi)) {
        $applyManagedIdentityName = $defaultApplyMi
    } else {
        $applyManagedIdentityName = $inputApplyMi
    }
    $defaults.ApplyManagedIdentityName = $applyManagedIdentityName

    # Do you want a Terraform state storage account? (default yes)
    $useTerraformStorage = Read-Host "Would you like to create a Terraform State Storage Account? [y/n]"
    if ([string]::IsNullOrWhiteSpace($useTerraformStorage)) { $useTerraformStorage = 'y' }
    if ($useTerraformStorage -match '^[yY]$') {
        do {
            $storageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)] (leave blank to skip)"
            if ([string]::IsNullOrWhiteSpace($storageAccountName)) {
                $storageAccountName = $null
                break
            }
            $valid = Test-StorageAccountName -StorageAccountName $storageAccountName
        } while (-not $valid)
        $defaults.TerraformStateStorageAccountName = $storageAccountName
    } else {
        $defaults.TerraformStateStorageAccountName = $null
    }

    return $defaults
}