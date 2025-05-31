Describe "Get-AzBootstrapLocalConfig" {
    BeforeAll {
        # Create a temporary directory for test files
        $TestDrive = Join-Path $TestDrive "AzBootstrapLocalConfigTests"
        New-Item -Path $TestDrive -ItemType Directory -Force | Out-Null

        # Load the private function directly for testing
        . "$PSScriptRoot/../private/Get-AzBootstrapLocalConfig.ps1"
    }

    AfterAll {
        # Cleanup
        if (Test-Path $TestDrive) {
            Remove-Item -Path $TestDrive -Recurse -Force
        }
    }

    Context "Reading local configuration file" {
        It "Should return null when config file doesn't exist" {
            # Arrange
            $configPath = Join-Path $TestDrive "nonexistent.jsonc"

            # Act
            $result = Get-AzBootstrapLocalConfig -ConfigPath $configPath

            # Assert
            $result | Should -Be $null
        }

        It "Should read valid config file successfully" {
            # Arrange
            $configPath = Join-Path $TestDrive "test-config.jsonc"
            $testConfig = @{
                schemaVersion = "1.0"
                environments = @{
                    dev = @{
                        EnvironmentName = "dev"
                        ResourceGroupName = "rg-test-dev"
                        DeploymentStackName = "azbootstrap-stack-dev-20250521123456"
                        PlanGitHubEnvironmentName = "dev-iac-plan"
                        ApplyGitHubEnvironmentName = "dev-iac-apply"
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            Set-Content -Path $configPath -Value $testConfig

            # Act
            $result = Get-AzBootstrapLocalConfig -ConfigPath $configPath

            # Assert
            $result | Should -Not -Be $null
            $result.schemaVersion | Should -Be "1.0"
            $result.environments.dev | Should -Not -Be $null
            $result.environments.dev.EnvironmentName | Should -Be "dev"
            $result.environments.dev.ResourceGroupName | Should -Be "rg-test-dev"
        }

        It "Should handle JSONC comments correctly" {
            # Arrange
            $configPath = Join-Path $TestDrive "test-config-with-comments.jsonc"
            $testConfigWithComments = @"
{
    // This is a comment
    "schemaVersion": "1.0",
    /* This is a 
       multi-line comment */
    "environments": {
        "dev": {
            "EnvironmentName": "dev", // inline comment
            "ResourceGroupName": "rg-test-dev"
        }
    }
}
"@
            
            Set-Content -Path $configPath -Value $testConfigWithComments

            # Act
            $result = Get-AzBootstrapLocalConfig -ConfigPath $configPath

            # Assert
            $result | Should -Not -Be $null
            $result.schemaVersion | Should -Be "1.0"
            $result.environments.dev.EnvironmentName | Should -Be "dev"
        }

        It "Should return null for invalid JSON" {
            # Arrange
            $configPath = Join-Path $TestDrive "invalid.jsonc"
            Set-Content -Path $configPath -Value "invalid json content {"

            # Act & Assert
            { Get-AzBootstrapLocalConfig -ConfigPath $configPath } | Should -Not -Throw
            $result = Get-AzBootstrapLocalConfig -ConfigPath $configPath
            $result | Should -Be $null
        }
    }

    Context "Auto-discovering config path" {
        It "Should return null when not in a git repository" {
            # Mock git command to fail
            Mock git { 
                $global:LASTEXITCODE = 1
                return $null 
            }

            # Act
            $result = Get-AzBootstrapLocalConfig

            # Assert
            $result | Should -Be $null
        }
    }
}