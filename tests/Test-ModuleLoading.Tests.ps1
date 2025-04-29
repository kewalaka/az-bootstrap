Describe "Module Loading Diagnostics" {
    BeforeAll {
        # Output the current location and PSScriptRoot to help diagnose path issues
        Write-Host "Current location before import: $(Get-Location)"
        Write-Host "PSScriptRoot: $PSScriptRoot"
        
        # Verify the module manifest file exists
        $manifestPath = "$PSScriptRoot/../az-bootstrap.psd1"
        Write-Host "Checking for module manifest at: $manifestPath"
        if (Test-Path $manifestPath) {
            Write-Host "✓ Module manifest exists"
        } else {
            Write-Host "✕ Module manifest not found!"
        }
        
        # Verify the root module file exists
        $rootModulePath = "$PSScriptRoot/../az-bootstrap.psm1"
        Write-Host "Checking for root module at: $rootModulePath"
        if (Test-Path $rootModulePath) {
            Write-Host "✓ Root module exists"
        } else {
            Write-Host "✕ Root module not found!"
        }
        
        # Check if function files exist
        $publicFunctionsPath = "$PSScriptRoot/../public"
        $privateFunctionsPath = "$PSScriptRoot/../private"
        
        Write-Host "Checking for public functions folder at: $publicFunctionsPath"
        if (Test-Path $publicFunctionsPath) {
            $publicFiles = Get-ChildItem -Path "$publicFunctionsPath/*.ps1" | Measure-Object
            Write-Host "✓ Public functions folder exists with $($publicFiles.Count) .ps1 files"
        } else {
            Write-Host "✕ Public functions folder not found!"
        }
        
        Write-Host "Checking for private functions folder at: $privateFunctionsPath"
        if (Test-Path $privateFunctionsPath) {
            $privateFiles = Get-ChildItem -Path "$privateFunctionsPath/*.ps1" | Measure-Object
            Write-Host "✓ Private functions folder exists with $($privateFiles.Count) .ps1 files"
        } else {
            Write-Host "✕ Private functions folder not found!"
        }
        
        # Try importing with verbose output
        Write-Host "Attempting to import module..."
        try {
            Import-Module $manifestPath -Force -Verbose
            Write-Host "✓ Module imported successfully"
            
            # Check if public function is available
            if (Get-Command -Name "New-AzBootstrap" -ErrorAction SilentlyContinue) {
                Write-Host "✓ New-AzBootstrap function is available"
            } else {
                Write-Host "✕ New-AzBootstrap function is NOT available!"
            }
            
            # Check a private function
            if (Get-Command -Name "Get-AzGitRepositoryInfo" -ErrorAction SilentlyContinue) {
                Write-Host "✓ Get-AzGitRepositoryInfo function is available"
            } else {
                Write-Host "✕ Get-AzGitRepositoryInfo function is NOT available!"
            }
        }
        catch {
            Write-Host "✕ Error importing module: $_"
        }
    }
    
    It "Placeholder test" {
        $true | Should -Be $true
    }
}