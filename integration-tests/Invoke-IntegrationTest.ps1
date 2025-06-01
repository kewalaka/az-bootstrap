param (
    [switch]$Cleanup
)

# Integration Test Script for az-bootstrap module
# This script performs an end-to-end test of the az-bootstrap module
# by creating a new repository from a template and deploying Azure resources.
#
# It runs in two modes:
# 1. Default: Create resources and validate
# 2. With -Cleanup: Delete resources created in first mode
#
# Requirements:
# - PowerShell 7.0+
# - Azure CLI authenticated with 'az login'
# - GitHub CLI authenticated with 'gh auth login'
# - Az PowerShell module installed
#
# Usage:
#   - To run the test:  ./Invoke-IntegrationTest.ps1
#   - To clean up:      ./Invoke-IntegrationTest.ps1 -Cleanup

# Setup
$ErrorActionPreference = 'Stop'
$start_location = Get-Location
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { "." }
Set-Location $scriptPath

# Import the module
Write-Host "Importing az-bootstrap module..."
try {
    Import-Module "$scriptPath/../az-bootstrap.psd1" -Force -ErrorAction Stop
    Write-Host "Module imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import az-bootstrap module: $_"
    exit 1
}

# Generate random names for resources to avoid conflicts
$randomSuffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
$timestamp = Get-Date -Format "yyyyMMdd"
$resourcePrefix = "azb-test"
$repoName = "$resourcePrefix-$timestamp-$randomSuffix"
$rgName = "rg-$repoName"
$resourceLocation = "newzealandnorth" # Default location, could be parameterized
$planMIName = "mi-$repoName-dev-plan"
$applyMIName = "mi-$repoName-dev-apply"
$storageAccountName = "st$($randomSuffix.ToLower())"

# Store test details in a state file for cleanup
$stateFile = Join-Path $scriptPath "integration-test-state.json"

function Invoke-TestSetup {
    Write-Host "Running integration test with random suffix: $randomSuffix"
    Write-Host "Target repository name: $repoName"
    Write-Host "Resource group name: $rgName"
    
    try {        
        # Call az-bootstrap with required parameters
        $params = @{
            TemplateRepoUrl                  = "https://github.com/kewalaka/terraform-azure-starter-template"
            TargetRepoName                   = $repoName
            ResourceGroupName                = $rgName
            Location                         = $resourceLocation
            PlanManagedIdentityName          = $planMIName
            ApplyManagedIdentityName         = $applyMIName
            TerraformStateStorageAccountName = $storageAccountName # Uncomment to test storage account creation
            SkipConfirmation                 = $true
        }
        
        Write-Host "Calling Invoke-AzBootstrap with parameters:" -ForegroundColor Cyan
        $params | Format-Table -AutoSize
        
        # Execute az-bootstrap
        $start = Get-Date

        try {
            $result = Invoke-AzBootstrap @params
            $end = Get-Date
            $duration = $end - $start

            Write-Host "Invoke-AzBootstrap completed in $($duration.TotalSeconds) seconds" -ForegroundColor Green
            Write-Host $result
        }
        catch {
            Write-Error "Invoke-AzBootstrap failed: $_"
            exit 1
        }
        finally {            
            # Store test state for cleanup
            $state = @{
                RepoName          = $repoName
                ResourceGroupName = $rgName
                Created           = (Get-Date).ToString('o')
                Duration          = $duration.TotalSeconds
            }
            
            $state | ConvertTo-Json | Out-File -FilePath $stateFile
        }
        
        # Verify repository was created
        Write-Host "Verifying repository creation..." -ForegroundColor Cyan
        $repoExists = $false
        $repoInfo = $null
        
        try {
            $ghOutput = gh repo view $repoName --json name,url,owner 2>$null
            if ($ghOutput) {
                $repoInfo = $ghOutput | ConvertFrom-Json
                $repoExists = ($repoInfo.name -eq $repoName)
            }
        }
        catch {
            Write-Warning "❌ Failed to verify repository existence: $_"
            $repoExists = $false
        }
        
        # Verify Azure resources were created
        Write-Host "Verifying Azure resources creation..." -ForegroundColor Cyan
        $rgExists = $false
        try {
            $rgInfo = az group show --name $rgName --query name -o tsv 2>$null
            $rgExists = ($rgInfo -eq $rgName)
            if ($rgExists) {
                Write-Host "✅ Resource group '$rgName' created successfully" -ForegroundColor Green
                
                # Check for managed identities with expected names
                Write-Host "Checking managed identities..."
                $identities = az identity list --resource-group $rgName --query "[].{name:name, principalId:principalId}" -o json 2>$null | ConvertFrom-Json

                if ($identities) {
                    $planMI = $identities | Where-Object { $_.name -eq $planMIName }
                    $applyMI = $identities | Where-Object { $_.name -eq $applyMIName }
                    
                    if ($planMI -and $applyMI) {
                        Write-Host "✅ Found both plan MI ($planMIName) and apply MI ($applyMIName)" -ForegroundColor Green
                    }
                    else {
                        if (-not $planMI) { Write-Warning "❌ Plan MI not found: $planMIName" }
                        if (-not $applyMI) { Write-Warning "❌ Apply MI not found: $applyMIName" }
                    }
                }
                else {
                    Write-Warning "❌ No managed identities found in resource group"
                }

                # Check for deployment stack
                Write-Host "Checking deployment stack..."
                $repoPath = Join-Path $scriptPath $repoName
                $configFile = Join-Path $repoPath ".azbootstrap.jsonc"

                if (Test-Path $configFile) {
                    try {
                        $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
                        if ($config.environments.dev.DeploymentStackName) {
                            $deploymentStack = $config.environments.dev.DeploymentStackName
                            Write-Host "✅ Found deployment stack from config: $deploymentStack" -ForegroundColor Green
                            
                            # Store stack name in state file for cleanup
                            $state.DeploymentStackName = $deploymentStack
                            $state | ConvertTo-Json | Out-File -FilePath $stateFile
                        }
                        else {
                            Write-Warning "❌ No deployment stack name found in .azbootstrap.jsonc"
                        }
                    }
                    catch {
                        Write-Warning "❌ Failed to parse .azbootstrap.jsonc: $_"
                    }
                }
                else {
                    Write-Warning "❌ Configuration file not found at: $configFile"
                }

                # Check storage account if we specified one
                if ($params.ContainsKey("TerraformStateStorageAccountName")) {
                    Write-Host "Checking storage account..."
                    $storageAccount = az storage account show --name $storageAccountName --resource-group $rgName --query name -o tsv 2>$null
                    
                    if ($storageAccount -eq $storageAccountName) {
                        Write-Host "✅ Found storage account: $storageAccountName" -ForegroundColor Green
                    }
                    else {
                        Write-Warning "❌ Storage account not found: $storageAccountName"
                    }
                }
            }
            else {
                Write-Warning "❌ Resource group '$rgName' does not exist or was not created"
                $rgExists = $false
            }
        }
        catch {
            Write-Warning "Failed to verify resource group: $_"
        }
        
        # Final test result
        if ($repoExists -and $rgExists) {
            Write-Host "`n✅ Integration test PASSED" -ForegroundColor Green
        }
        else {            
            Write-Error "❌ Integration test FAILED. (Repository exists: $repoExists, Resource group exists: $rgExists)"
            exit 1
        }
    }
    catch {
        Write-Error "❌ Integration test triggered exception: $_"
        exit 1
    }
    finally {
        # Return to original directory
        Set-Location $start_location
    }
}

function Invoke-TestCleanup {
    if (-not (Test-Path $stateFile)) {
        Write-Warning "State file not found. Cannot perform cleanup."
        return
    }
    
    try {
        # Load state from file
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        
        Write-Host "Performing cleanup of test resources..." -ForegroundColor Yellow
        Write-Host "Repository: $($state.RepoName)"
        Write-Host "Resource Group: $($state.ResourceGroupName)"
        
        $errors = @()
        
        # Delete the GitHub repository
        Write-Host "Deleting GitHub repository..." -ForegroundColor Yellow
        try {
            $repoExists = $null 
            $repoExists = gh repo view $state.RepoName --json name 2>$null
            
            if ($repoExists) {
                Write-Host "Repository exists, deleting..."
                $repoDeleteResult = gh repo delete $state.RepoName --yes 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Repository deleted successfully" -ForegroundColor Green
                }
                else {
                    $errors += "Failed to delete repository: $repoDeleteResult"
                    Write-Warning $errors[-1]
                }
            }
            else {
                Write-Host "Repository doesn't exist or is not accessible, skipping deletion"
            }
        }
        catch {
            $errors += "Error during repository deletion check: $_"
            Write-Warning $errors[-1]
        }

        # Delete the local repository clone
        Write-Host "Deleting local repository clone..." -ForegroundColor Yellow
        try {
            $repoPath = Join-Path $scriptPath $state.RepoName
            if (Test-Path $repoPath) {
                Write-Host "Local repository exists at $repoPath, deleting..."
                # Use -Force to handle read-only files and -Recurse for directories
                Remove-Item -Path $repoPath -Recurse -Force -ErrorAction Stop
                Write-Host "Local repository deleted successfully" -ForegroundColor Green
            }
            else {
                Write-Host "Local repository directory not found at $repoPath, skipping deletion"
            }
        }
        catch {
            $errors += "Error deleting local repository: $_"
            Write-Warning $errors[-1]
        }

        # use stack deletion when possible
        if ($state.DeploymentStackName) {
            Write-Host "Deleting Azure deployment stack..." -ForegroundColor Yellow
            try {
                $stackExists = az stack sub show --name $state.DeploymentStackName 2>$null
                
                if ($stackExists) {
                    Write-Host "Deployment stack exists, deleting..."
                    $stackDeleteResult = az stack sub delete --name $state.DeploymentStackName --action-on-unmanage deleteResources --yes 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Deployment stack deletion successful" -ForegroundColor Green
                        # Since stack deletion removes all resources, we can skip RG deletion
                        $skipRGDeletion = $true
                    }
                    else {
                        $errors += "Failed to delete deployment stack: $stackDeleteResult"
                        Write-Warning $errors[-1]
                    }
                }
                else {
                    Write-Host "Deployment stack doesn't exist, falling back to resource group deletion"
                }
            }
            catch {
                $errors += "Error during deployment stack deletion: $_"
                Write-Warning $errors[-1]
                Write-Host "Falling back to resource group deletion..."
            }
        }

        # Only delete RG if stack deletion was not successful
        if (-not $skipRGDeletion) {        
            # Delete the Azure resource group using Azure CLI
            Write-Host "Deleting Azure resource group..." -ForegroundColor Yellow
            try {
                $rgExists = az group exists --name $state.ResourceGroupName | ConvertFrom-Json
                
                if ($rgExists) {
                    Write-Host "Resource group exists, deleting..."
                    $rgDeleteResult = az group delete --name $state.ResourceGroupName --yes --no-wait 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Resource group deletion initiated successfully" -ForegroundColor Green
                    }
                    else {
                        $errors += "Failed to delete resource group: $rgDeleteResult"
                        Write-Warning $errors[-1]
                    }
                }
                else {
                    Write-Host "Resource group doesn't exist, skipping deletion"
                }
            }
            catch {
                $errors += "Error during resource group deletion: $_"
                Write-Warning $errors[-1]
            }
        }

        # Clean up state file if everything succeeded
        if ($errors.Count -eq 0) {
            Remove-Item $stateFile -Force
            Write-Host "Cleanup completed successfully" -ForegroundColor Green
        }
        else {
            Write-Warning "Cleanup completed with $($errors.Count) warnings/errors"
        }
    }
    catch {
        Write-Error "Cleanup failed: $_"
        exit 1
    }
    finally {
        # Return to original directory
        Set-Location $start_location
    }
}

# Main execution
if ($Cleanup) {
    Invoke-TestCleanup
}
else {
    Invoke-TestSetup
}