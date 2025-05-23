function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Initial empty defaults - we'll populate after getting target repo name
    $defaults = @{
        TemplateRepoUrl   = ""
        TargetRepoName    = ""
        Location          = ""
        ResourceGroupName = ""
        PlanManagedIdentityName = ""
        ApplyManagedIdentityName = ""
        TerraformStateStorageAccountName = ""
    }

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

    # Prompt for target repo name
    $targetRepoName = Read-Host "Enter Target Repository Name"
    if ([string]::IsNullOrWhiteSpace($targetRepoName)) {
        Write-Host "Target Repository Name is required." -ForegroundColor Red
        $targetRepoName = Read-Host "Enter Target Repository Name"
        if ([string]::IsNullOrWhiteSpace($targetRepoName)) {
            throw "Target Repository Name is required to proceed."
        }
    }
    $defaults.TargetRepoName = $targetRepoName
    
    # Set environment name to default "dev" for naming purposes
    $env = "dev"
    
    # Generate CAF-aligned names based on the target repo name
    $defaultResourceGroupName = "rg$env"
    $defaultPlanMIName = "mi$targetRepoName$env-plan"
    $defaultApplyMIName = "mi$targetRepoName$env-apply"
    # Generate storage account name with random padding for uniqueness
    $randomPadding = Get-Random -Minimum 100 -Maximum 999
    $defaultStorageName = "st$targetRepoName$env$randomPadding".ToLower()
    # Ensure storage name is valid (lowercase alphanumeric only, and max 24 chars)
    $defaultStorageName = $defaultStorageName -replace '[^a-z0-9]', ''
    if ($defaultStorageName.Length -gt 24) {
        $defaultStorageName = $defaultStorageName.Substring(0, 24)
    }

    # Prompt for location
    $location = Read-Host "Enter Azure Location [australiaeast]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = "australiaeast"
    }
    $defaults.Location = $location

    # Prompt for resource group name with CAF-aligned default
    $resourceGroupName = Read-Host "Enter Resource Group Name [$defaultResourceGroupName]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaultResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Prompt for Plan MI name with CAF-aligned default
    $planManagedIdentityName = Read-Host "Enter Plan Managed Identity Name [$defaultPlanMIName]"
    if ([string]::IsNullOrWhiteSpace($planManagedIdentityName)) {
        $planManagedIdentityName = $defaultPlanMIName
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Prompt for Apply MI name with CAF-aligned default
    $applyManagedIdentityName = Read-Host "Enter Apply Managed Identity Name [$defaultApplyMIName]"
    if ([string]::IsNullOrWhiteSpace($applyManagedIdentityName)) {
        $applyManagedIdentityName = $defaultApplyMIName
    }
    $defaults.ApplyManagedIdentityName = $applyManagedIdentityName

    # Prompt for storage account name with CAF-aligned default
    $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [$defaultStorageName]"
    if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
        $terraformStateStorageAccountName = $defaultStorageName
    }
    # Validate storage account name format
    if ($terraformStateStorageAccountName -notmatch "^[a-z0-9]{3,24}$") {
        Write-Host "Storage account name must be 3-24 characters long and contain only lowercase letters and numbers." -ForegroundColor Yellow
        $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [$defaultStorageName]"
        if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
            $terraformStateStorageAccountName = $defaultStorageName
        }
    }
    $defaults.TerraformStateStorageAccountName = $terraformStateStorageAccountName

    # Display summary of configuration
    Write-Host "`n--- Configuration Summary ---" -ForegroundColor Green
    Write-Host "Template Repository URL      : $($defaults.TemplateRepoUrl)"
    Write-Host "Target Repository Name       : $($defaults.TargetRepoName)"
    Write-Host "Azure Location               : $($defaults.Location)"
    Write-Host "Resource Group Name          : $($defaults.ResourceGroupName)"
    Write-Host "Plan Managed Identity Name   : $($defaults.PlanManagedIdentityName)"
    Write-Host "Apply Managed Identity Name  : $($defaults.ApplyManagedIdentityName)"
    Write-Host "Terraform State Storage Name : $($defaults.TerraformStateStorageAccountName)"
    Write-Host "----------------------------" -ForegroundColor Green

    # Prompt for confirmation
    $confirmation = Read-Host "`nProceed with this configuration? (y/N)"
    
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Bootstrap operation cancelled." -ForegroundColor Yellow
        return $null
    }

    return $defaults
}