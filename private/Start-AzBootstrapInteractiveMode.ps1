function Start-AzBootstrapInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Defaults
    )

    $defaults = $Defaults

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

    # Prompt for storage account name with CAF-aligned default
    $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)]"
    if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
        $terraformStateStorageAccountName = $defaults.TerraformStateStorageAccountName
    }
    # Validate storage account name format
    if ($terraformStateStorageAccountName -notmatch "^[a-z0-9]{3,24}$") {
        Write-Host "Storage account name must be 3-24 characters long and contain only lowercase letters and numbers." -ForegroundColor Yellow
        $terraformStateStorageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)]"
        if ([string]::IsNullOrWhiteSpace($terraformStateStorageAccountName)) {
            $terraformStateStorageAccountName = $defaults.TerraformStateStorageAccountName
        }
    }
    $defaults.TerraformStateStorageAccountName = $terraformStateStorageAccountName

    return $defaults
}