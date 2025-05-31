function Start-AzBootstrapEnvironmentInteractiveMode {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$defaults
    )

    Write-Host "`n" -NoNewline
    Write-BootstrapLog "Interactive Mode - Adding new environment. Enter required values or press Enter to accept defaults`n"

    # Environment name is always required
    if ([string]::IsNullOrWhiteSpace($defaults.EnvironmentName)) {
        do {
            $environmentName = Read-Host "Enter Environment Name (e.g., test, prod, staging)"
            if ([string]::IsNullOrWhiteSpace($environmentName)) {
                Write-Host "Environment Name cannot be empty."
            } 
        } while ([string]::IsNullOrWhiteSpace($environmentName))
        $defaults.EnvironmentName = $environmentName
    }

    # Location
    $location = Read-Host "Enter Azure Location [$($defaults.Location)]"
    if (-not [string]::IsNullOrWhiteSpace($location)) {
        $defaults.Location = $location
    }

    # Resource Group - derive default from environment name and project pattern
    if ([string]::IsNullOrWhiteSpace($defaults.ResourceGroupName)) {
        # Try to derive project name from existing environments or use a default pattern
        $projectBaseName = if ($defaults.ProjectBaseName) {
            $defaults.ProjectBaseName
        } else {
            "project"  # fallback if we can't determine the project name
        }
        $defaults.ResourceGroupName = "rg-$projectBaseName-$($defaults.EnvironmentName)"
    }
    
    $resourceGroupName = Read-Host "Enter Resource Group Name [$($defaults.ResourceGroupName)]"
    if (-not [string]::IsNullOrWhiteSpace($resourceGroupName)) {
        $defaults.ResourceGroupName = $resourceGroupName
    }

    # Plan Managed Identity - derive default using helper function
    if ([string]::IsNullOrWhiteSpace($defaults.PlanManagedIdentityName)) {
        $projectBaseName = if ($defaults.ProjectBaseName) {
            $defaults.ProjectBaseName
        } else {
            "project"  # fallback
        }
        $defaults.PlanManagedIdentityName = Get-ManagedIdentityName -BaseName $projectBaseName -Environment $defaults.EnvironmentName -Type 'plan'
    }
    
    $planManagedIdentityName = Read-Host "Enter Plan Managed Identity Name [$($defaults.PlanManagedIdentityName)]"
    if (-not [string]::IsNullOrWhiteSpace($planManagedIdentityName)) {
        $defaults.PlanManagedIdentityName = $planManagedIdentityName
    }

    # Apply Managed Identity - derive default using helper function
    if ([string]::IsNullOrWhiteSpace($defaults.ApplyManagedIdentityName)) {
        $projectBaseName = if ($defaults.ProjectBaseName) {
            $defaults.ProjectBaseName
        } else {
            "project"  # fallback
        }
        $defaults.ApplyManagedIdentityName = Get-ManagedIdentityName -BaseName $projectBaseName -Environment $defaults.EnvironmentName -Type 'apply'
    }
    
    $applyManagedIdentityName = Read-Host "Enter Apply Managed Identity Name [$($defaults.ApplyManagedIdentityName)]"
    if (-not [string]::IsNullOrWhiteSpace($applyManagedIdentityName)) {
        $defaults.ApplyManagedIdentityName = $applyManagedIdentityName
    }

    # Optional: Terraform state storage account
    $useTerraformStorage = Read-Host "Would you like to specify a Terraform State Storage Account? [y/N]"
    if ($useTerraformStorage -match '^[yY]$') {
        # Generate a default if not provided
        if ([string]::IsNullOrWhiteSpace($defaults.TerraformStateStorageAccountName)) {
            $randomPadding = Get-Random -Minimum 100 -Maximum 999
            $projectBaseName = if ($defaults.ProjectBaseName) { $defaults.ProjectBaseName } else { "project" }
            $defaultStorageAccountName = "st$projectBaseName$($defaults.EnvironmentName)$randomPadding" -replace '[^a-z0-9]', ''
            if ($defaultStorageAccountName.Length -gt 24) { 
                $defaultStorageAccountName = $defaultStorageAccountName.Substring(0, 24) 
            }
            $defaults.TerraformStateStorageAccountName = $defaultStorageAccountName
        }
        
        do {
            $storageAccountName = Read-Host "Enter Terraform State Storage Account Name [$($defaults.TerraformStateStorageAccountName)]"
            if ([string]::IsNullOrWhiteSpace($storageAccountName)) {
                $storageAccountName = $defaults.TerraformStateStorageAccountName
            }
            if (-not [string]::IsNullOrWhiteSpace($storageAccountName)) {
                Write-BootstrapLog "Checking if Storage Account '$storageAccountName' is valid and available..."
                $valid = Test-AzStorageAccountName -StorageAccountName $storageAccountName
            } else {
                $valid = $true  # Allow empty storage account name
            }
        } while (-not $valid)
        $defaults.TerraformStateStorageAccountName = $storageAccountName
    }

    Write-Host "`n" -NoNewline

    return $defaults
}