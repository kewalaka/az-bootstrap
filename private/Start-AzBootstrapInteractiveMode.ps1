function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Default values for interactive mode
    $defaults = @{
        TemplateRepoUrl   = ""
        TargetRepoName    = ""
        Location          = ""
        ResourceGroupName = "azb-rg"
        PlanManagedIdentityName = "azb-mi-plan"
        ApplyManagedIdentityName = "azb-mi-apply"
        TerraformStateStorageAccountName = "azbstorage"
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

    # Prompt for location
    $location = Read-Host "Enter Azure Location [australiaeast]"
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = "australiaeast"
    }
    $defaults.Location = $location

    # Prompt for resource group name
    $resourceGroupName = Read-Host "Enter Resource Group Name [azb-rg]"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $resourceGroupName = $defaults.ResourceGroupName
    }
    $defaults.ResourceGroupName = $resourceGroupName

    # Prompt for MI name
    $planManagedIdentityName = Read-Host "Enter Plan Managed Identity Name [azb-mi-plan]"
    if ([string]::IsNullOrWhiteSpace($planManagedIdentityName)) {
        $planManagedIdentityName = $defaults.PlanManagedIdentityName
    }
    $defaults.PlanManagedIdentityName = $planManagedIdentityName

    # Derive apply MI name from plan MI name if not specified
    $applyManagedIdentityName = Read-Host "Enter Apply Managed Identity Name [azb-mi-apply]"
    if ([string]::IsNullOrWhiteSpace($applyManagedIdentityName)) {
        $applyManagedIdentityName = $defaults.ApplyManagedIdentityName
    }
    $defaults.ApplyManagedIdentityName = $applyManagedIdentityName

    # Prompt for storage account name
    $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [azbstorage]"
    if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
        $terraformStateStorageAccountName = $defaults.TerraformStateStorageAccountName
    }
    # Validate storage account name format
    if ($terraformStateStorageAccountName -notmatch "^[a-z0-9]{3,24}$") {
        Write-Host "Storage account name must be 3-24 characters long and contain only lowercase letters and numbers." -ForegroundColor Yellow
        $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [azbstorage]"
        if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
            $terraformStateStorageAccountName = $defaults.TerraformStateStorageAccountName
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