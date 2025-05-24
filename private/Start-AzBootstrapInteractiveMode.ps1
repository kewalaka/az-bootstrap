function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$defaults
    )

    Write-Host "`n[az-bootstrap] Interactive Mode - Enter required values or press Enter to accept defaults`n" -ForegroundColor Cyan

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

    # Generate default resource and identity names (CAF-aligned)
    $env = 'dev'
    # Default storage account name
    $randomPadding = Get-Random -Minimum 100 -Maximum 999
    $storageDefault = "st$($defaults.TargetRepoName)$env$randomPadding" -replace '[^a-z0-9]', ''
    if ($storageDefault.Length -gt 24) { $storageDefault = $storageDefault.Substring(0,24) }
    $defaults.TerraformStateStorageAccountName = $storageDefault

    # Prompt for Azure Location
    $location = Read-Host "Enter Azure Location [$($defaults.Location)]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = $defaults.Location
    }
    $defaults.Location = $location

    # Prompt for resource group name with CAF-aligned default
    $resourceGroupName = Read-Host "Enter Resource Group Name [$($defaults.ResourceGroupName)]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaults.ResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Prompt for Plan MI name with CAF-aligned default
    $planManagedIdentityName = Read-Host "Enter Plan Managed Identity Name [$($defaults.PlanManagedIdentityName)]"
    if ([string]::IsNullOrWhiteSpace($planManagedIdentityName)) {
        $planManagedIdentityName = $defaults.PlanManagedIdentityName
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Prompt for Apply MI name with CAF-aligned default
    $applyManagedIdentityName = Read-Host "Enter Apply Managed Identity Name [$($defaults.ApplyManagedIdentityName)]"
    if ([string]::IsNullOrWhiteSpace($applyManagedIdentityName)) {
        $applyManagedIdentityName = $defaults.ApplyManagedIdentityName
    }
    $defaults.ApplyManagedIdentityName = $applyManagedIdentityName

    # Prompt if user wants a Terraform state storage account (default yes)
    $useTerraformStorage = Read-Host "Would you like to create a Terraform State Storage Account? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($useTerraformStorage)) { $useTerraformStorage = 'y' }
    if ($useTerraformStorage -match '^[yY]$') {
        # Loop until valid name or blank to skip
        do {
            $storageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)] (leave blank to skip)"
            if ([string]::IsNullOrWhiteSpace($input)) {
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