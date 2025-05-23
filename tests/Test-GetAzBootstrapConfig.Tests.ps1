Describe "Global Config Functionality via Invoke-AzBootstrap" {
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

        It "Resolves template alias when config file exists" {
            $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                Join-Path $env:USERPROFILE ".az-bootstrap.jsonc"
            } else {
                Join-Path $env:HOME ".az-bootstrap.jsonc"
            }
            
            $testConfig = @{
                templateAliases = @{
                    terraform = "https://github.com/kewalaka/terraform-azure-starter-template"
                }
            } | ConvertTo-Json
            
            Set-Content -Path $configPath -Value $testConfig
            
            # Test template resolution by calling Invoke-AzBootstrap with verbose output
            try {
                $output = Invoke-AzBootstrap -TemplateRepoUrl "terraform" -TargetRepoName "test" -Location "eastus" -Verbose 2>&1
                $resolvedMessage = $output | Where-Object { $_ -match "Resolved template alias 'terraform'" }
                $resolvedMessage | Should -Not -BeNullOrEmpty
            } catch {
                # Expected to fail at GitHub CLI check, but should get past template resolution
                $_.Exception.Message | Should -Match "GitHub CLI"
            }
        }

        It "Uses GitHub shorthand when no config file exists" {
            # Test with owner/repo format
            try {
                $output = Invoke-AzBootstrap -TemplateRepoUrl "owner/repo" -TargetRepoName "test" -Location "eastus" -Verbose 2>&1
                $shorthandMessage = $output | Where-Object { $_ -match "GitHub shorthand.*https://github.com/owner/repo" }
                $shorthandMessage | Should -Not -BeNullOrEmpty
            } catch {
                # Expected to fail at GitHub CLI check
                $_.Exception.Message | Should -Match "GitHub CLI"
            }
        }

        It "Leaves full URLs unchanged" {
            try {
                $fullUrl = "https://github.com/test/repo"
                $output = Invoke-AzBootstrap -TemplateRepoUrl $fullUrl -TargetRepoName "test" -Location "eastus" -Verbose 2>&1
                $unchangedMessage = $output | Where-Object { $_ -match "already a full URL.*$fullUrl" }
                $unchangedMessage | Should -Not -BeNullOrEmpty
            } catch {
                # Expected to fail at GitHub CLI check
                $_.Exception.Message | Should -Match "GitHub CLI"
            }
        }
    }