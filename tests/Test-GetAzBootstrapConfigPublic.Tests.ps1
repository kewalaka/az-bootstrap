Describe "Get-AzBootstrapConfig Public Function" {
    BeforeAll { 
        # Import the module
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
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

    It "Displays configuration file path when file doesn't exist" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Make sure file doesn't exist
        if (Test-Path $configPath) {
            Remove-Item $configPath -Force
        }
        
        # Capture output
        $output = Get-AzBootstrapConfig -Verbose 2>&1
        $outputString = $output | Out-String
        
        # Verify output
        $outputString | Should -Match "Configuration file path: .*\.az-bootstrap\.jsonc"
        $outputString | Should -Match "Configuration file does not exist"
    }
    
    It "Displays template aliases and default location when config exists" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Create a config file with aliases and default location
        $testConfig = @{
            templateAliases = @{
                terraform = "https://github.com/example/terraform-template"
                bicep = "https://github.com/example/bicep-template"
            }
            defaultLocation = "eastus"
        }
        $testConfig | ConvertTo-Json | Set-Content -Path $configPath
        
        # Capture output
        $output = Get-AzBootstrapConfig -Verbose 2>&1
        $outputString = $output | Out-String
        
        # Verify output contains the expected information
        $outputString | Should -Match "Configuration file path: .*\.az-bootstrap\.jsonc"
        $outputString | Should -Match "Template Aliases:"
        $outputString | Should -Match "terraform ->"
        $outputString | Should -Match "bicep ->"
        $outputString | Should -Match "Default Location: eastus"
    }
    
    It "Returns the configuration object for pipeline use" {
        # Get the expected config path
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
        } else {
            Join-Path $env:HOME ".az-bootstrap.jsonc"
        }
        
        # Create a config file with aliases and default location
        $testConfig = @{
            templateAliases = @{
                terraform = "https://github.com/example/terraform-template"
            }
            defaultLocation = "eastus"
        }
        $testConfig | ConvertTo-Json | Set-Content -Path $configPath
        
        # Get the config and verify it's a object with expected properties
        $config = Get-AzBootstrapConfig
        $config | Should -Not -BeNullOrEmpty
        $config.templateAliases | Should -Not -BeNullOrEmpty
        $config.templateAliases.terraform | Should -Be "https://github.com/example/terraform-template"
        $config.defaultLocation | Should -Be "eastus"
    }
}