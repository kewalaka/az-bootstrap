Describe "Set-AzBootstrapConfig" {
    BeforeAll { 
        # Import the module
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
        
        # Manually dot source the function files if they're not loaded
        . "$PSScriptRoot/../public/Set-AzBootstrapConfig.ps1"
    }
    
    BeforeEach {
        # Store original environment variables
        $originalUserProfile = $env:USERPROFILE
        $originalHome = $env:HOME
        
        # Create a temporary directory for testing
        $testDir = New-Item -ItemType Directory -Path (Join-Path $TestDrive "testuser") -Force
        
        # Set test environment variables
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            $env:USERPROFILE = $testDir.FullName
        } else {
            $env:HOME = $testDir.FullName
        }
    }
    
    AfterEach {
        # Restore original environment variables
        $env:USERPROFILE = $originalUserProfile
        $env:HOME = $originalHome
    }

    It "Creates a new configuration file with template alias" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Test that the config file doesn't exist
        Test-Path $configPath | Should -Be $false
        
        # Set a template alias
        Set-AzBootstrapConfig -TemplateAlias "terraform" -Value "https://github.com/example/terraform-template"
        
        # Test that the config file exists
        Test-Path $configPath | Should -Be $true
        
        # Read the content and verify
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.templateAliases["terraform"] | Should -Be "https://github.com/example/terraform-template"
    }
    
    It "Updates an existing template alias" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Create a config file with an existing alias
        $initialConfig = @{
            templateAliases = @{
                terraform = "https://github.com/old/terraform-template"
            }
        }
        $initialConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
        
        # Update the template alias
        Set-AzBootstrapConfig -TemplateAlias "terraform" -Value "https://github.com/new/terraform-template"
        
        # Read the content and verify it was updated
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.templateAliases["terraform"] | Should -Be "https://github.com/new/terraform-template"
    }
    
    It "Adds a new alias to existing configuration" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Create a config file with an existing different alias
        $initialConfig = @{
            templateAliases = @{
                terraform = "https://github.com/example/terraform-template"
            }
            defaultLocation = "eastus"
        }
        # Convert config to JSON and check that we got expected content
        $initialConfigJson = $initialConfig | ConvertTo-Json -Depth 10
        $initialConfigJson | Should -Match "terraform"
        $initialConfigJson | Should -Match "eastus"
        
        # Write the JSON to file
        $initialConfigJson | Set-Content -Path $configPath
        
        # Add a new template alias
        Set-AzBootstrapConfig -TemplateAlias "bicep" -Value "https://github.com/example/bicep-template"
        
        # Read the content and verify it contains what we expect
        $configJson = Get-Content -Path $configPath -Raw 
        $configJson | Should -Match "terraform"
        $configJson | Should -Match "bicep"
        $configJson | Should -Match "eastus"
    }
}