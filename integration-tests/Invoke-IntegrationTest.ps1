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
$resourceLocation = "eastus" # Default location, could be parameterized

# Store test details in a state file for cleanup
$stateFile = Join-Path $scriptPath "integration-test-state.json"

function Invoke-TestSetup {
    Write-Host "Running integration test with random suffix: $randomSuffix"
    Write-Host "Target repository name: $repoName"
    Write-Host "Resource group name: $rgName"
    
    try {
        # Check prerequisites
        Write-Host "Checking Azure CLI login status..."
        $azLogin = az account show --output json 2>$null | ConvertFrom-Json
        if (-not $azLogin) {
            throw "Not logged in to Azure. Please run 'az login' first."
        }
        Write-Host "Azure CLI authenticated as: $($azLogin.user.name)"

        Write-Host "Checking GitHub CLI login status..."
        try {
            $ghLogin = gh auth status --show-token 2>$null
            if (-not $ghLogin) {
                throw "GitHub CLI not authenticated"
            }
            Write-Host "GitHub CLI authenticated"
        }
        catch {
            throw "GitHub CLI not authenticated or error checking status: $_"
        }
        
        # Call az-bootstrap with required parameters
        # Note: -Confirm:$false is used for non-interactive mode
        $params = @{
            TemplateRepoUrl = "https://github.com/kewalaka/terraform-azure-starter-template"
            TargetRepoName = $repoName
            ResourceGroupName = $rgName
            Location = $resourceLocation
            Confirm = $false
        }
        
        Write-Host "Calling Invoke-AzBootstrap with parameters:" -ForegroundColor Cyan
        $params | Format-Table -AutoSize
        
        # Execute az-bootstrap
        $start = Get-Date
        $result = Invoke-AzBootstrap @params
        $end = Get-Date
        $duration = $end - $start
        
        Write-Host "Invoke-AzBootstrap completed in $($duration.TotalSeconds) seconds" -ForegroundColor Green
        
        # Store test state for cleanup
        $state = @{
            RepoName = $repoName
            ResourceGroupName = $rgName
            Created = (Get-Date).ToString('o')
            Duration = $duration.TotalSeconds
        }
        
        $state | ConvertTo-Json | Out-File -FilePath $stateFile
        
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
            Write-Warning "Failed to verify repository existence: $_"
            $repoExists = $false
        }
        
        # Verify Azure resources were created
        Write-Host "Verifying Azure resources creation..." -ForegroundColor Cyan
        $rgExists = $false
        try {
            $rgInfo = az group show --name $rgName --query name -o tsv 2>$null
            $rgExists = ($rgInfo -eq $rgName)
            if ($rgExists) {
                Write-Host "Resource group '$rgName' created successfully" -ForegroundColor Green
                
                # Check for managed identities
                Write-Host "Checking managed identities..."
                $identities = az identity list --resource-group $rgName --query "[].name" -o tsv 2>$null
                if ($identities) {
                    Write-Host "Found managed identities: $identities" -ForegroundColor Green
                }
                else {
                    Write-Warning "No managed identities found in resource group"
                }
            }
        }
        catch {
            Write-Warning "Failed to verify resource group: $_"
        }
        
        # Final test result
        if ($repoExists -and $rgExists) {
            Write-Host "`n✅ Integration test PASSED" -ForegroundColor Green
            Write-Host "Repository URL: $($repoInfo.url)" -ForegroundColor Green
            Write-Host "Resource Group: $rgName" -ForegroundColor Green
        }
        else {
            $failures = @()
            if (-not $repoExists) { $failures += "Repository creation" }
            if (-not $rgExists) { $failures += "Resource Group creation" }
            
            Write-Error "❌ Integration test FAILED. Issues with: $($failures -join ', ')"
            exit 1
        }
    }
    catch {
        Write-Error "Integration test failed: $_"
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
                } else {
                    $errors += "Failed to delete repository: $repoDeleteResult"
                    Write-Warning $errors[-1]
                }
            } else {
                Write-Host "Repository doesn't exist or is not accessible, skipping deletion"
            }
        }
        catch {
            $errors += "Error during repository deletion check: $_"
            Write-Warning $errors[-1]
        }
        
        # Delete the Azure resource group using Azure CLI
        Write-Host "Deleting Azure resource group..." -ForegroundColor Yellow
        try {
            $rgExists = az group exists --name $state.ResourceGroupName | ConvertFrom-Json
            
            if ($rgExists) {
                Write-Host "Resource group exists, deleting..."
                $rgDeleteResult = az group delete --name $state.ResourceGroupName --yes --no-wait 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Resource group deletion initiated successfully" -ForegroundColor Green
                } else {
                    $errors += "Failed to delete resource group: $rgDeleteResult"
                    Write-Warning $errors[-1]
                }
            } else {
                Write-Host "Resource group doesn't exist, skipping deletion"
            }
        }
        catch {
            $errors += "Error during resource group deletion: $_"
            Write-Warning $errors[-1]
        }
        
        # Clean up state file if everything succeeded
        if ($errors.Count -eq 0) {
            Remove-Item $stateFile -Force
            Write-Host "Cleanup completed successfully" -ForegroundColor Green
        } else {
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