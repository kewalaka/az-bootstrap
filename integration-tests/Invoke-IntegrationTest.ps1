param (
    [switch]$Cleanup
)

# Script to perform end-to-end integration test of az-bootstrap module
# This runs in two modes:
# 1. Default: Create resources and validate
# 2. With -Cleanup: Delete resources created in first mode

# Setup
$ErrorActionPreference = 'Stop'
$start_location = Get-Location
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { "." }
Set-Location $scriptPath

# Import the module
Write-Host "Importing az-bootstrap module..."
Import-Module "$scriptPath/../az-bootstrap.psd1" -Force -ErrorAction Stop

# Generate random names for resources to avoid conflicts
$randomSuffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
$resourcePrefix = "azb-test"
$repoName = "$resourcePrefix-$randomSuffix"
$rgName = "rg-$repoName"
$resourceLocation = "eastus" # Default location, could be parameterized

# Store test details in a state file for cleanup
$stateFile = Join-Path $scriptPath "integration-test-state.json"

function Invoke-TestSetup {
    Write-Host "Running integration test with random suffix: $randomSuffix"
    Write-Host "Target repository name: $repoName"
    Write-Host "Resource group name: $rgName"
    
    try {
        # Call az-bootstrap with required parameters
        # Note: -Confirm:$false is used for non-interactive mode
        $params = @{
            TemplateRepoUrl = "https://github.com/kewalaka/terraform-azure-starter-template"
            TargetRepoName = $repoName
            ResourceGroupName = $rgName
            Location = $resourceLocation
            Confirm = $false
        }
        
        Write-Host "Calling Invoke-AzBootstrap with parameters:"
        $params | Format-Table -AutoSize
        
        # Execute az-bootstrap
        $result = Invoke-AzBootstrap @params
        
        # Store test state for cleanup
        $state = @{
            RepoName = $repoName
            ResourceGroupName = $rgName
            Created = (Get-Date).ToString('o')
        }
        
        $state | ConvertTo-Json | Out-File -FilePath $stateFile
        
        # Verify repository was created
        Write-Host "Verifying repository creation..."
        $repoExists = $false
        try {
            $repoInfo = Invoke-Expression "gh repo view $repoName --json name,url" | ConvertFrom-Json
            $repoExists = ($repoInfo.name -eq $repoName)
        }
        catch {
            Write-Error "Failed to verify repository existence: $_"
            $repoExists = $false
        }
        
        if ($repoExists) {
            Write-Host "Repository created successfully: $($repoInfo.url)" -ForegroundColor Green
        }
        else {
            Write-Error "Repository was not created successfully"
            exit 1
        }
        
        Write-Host "Integration test completed successfully" -ForegroundColor Green
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
        
        # Delete the GitHub repository
        Write-Host "Deleting GitHub repository..."
        $repoDeleteResult = $null
        try {
            $repoDeleteResult = Invoke-Expression "gh repo delete $($state.RepoName) --yes"
            Write-Host "Repository deleted successfully" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to delete repository: $_"
        }
        
        # Delete the Azure resource group using Azure CLI
        Write-Host "Deleting Azure resource group..."
        $rgDeleteResult = $null
        try {
            # Note: Using az group delete directly as it's more reliable for cleanup
            $rgDeleteResult = Invoke-Expression "az group delete --name $($state.ResourceGroupName) --yes --no-wait"
            Write-Host "Resource group deletion initiated" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to delete resource group: $_"
        }
        
        # Clean up state file
        Remove-Item $stateFile -Force
        
        Write-Host "Cleanup completed" -ForegroundColor Green
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