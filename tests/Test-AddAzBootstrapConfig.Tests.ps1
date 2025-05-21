Describe "Add-AzBootstrapConfig" {
    BeforeAll {
        # Create a temporary directory for test files
        $TestDrive = Join-Path $TestDrive "AzBootstrapTests"
        New-Item -Path $TestDrive -ItemType Directory -Force | Out-Null

        # Load the private function directly for testing
        . "$PSScriptRoot/../private/Add-AzBootstrapConfig.ps1"
    }

    AfterAll {
        # Cleanup
        if (Test-Path $TestDrive) {
            Remove-Item -Path $TestDrive -Recurse -Force
        }
    }

    Context "Creating a new configuration file" {
        It "Should create a new config file with the correct structure" {
            # Arrange
            $configPath = Join-Path $TestDrive "test-config.jsonc"
            $environmentName = "test-env"
            $environmentConfig = [PSCustomObject]@{
                EnvironmentName = $environmentName
                ResourceGroupName = "rg-test"
                Location = "eastus"
                PlanManagedIdentityName = "mi-test-plan"
                ApplyManagedIdentityName = "mi-test-apply"
                PlanGitHubEnvironmentName = "test-env-iac-plan"
                ApplyGitHubEnvironmentName = "test-env-iac-apply"
                PlanManagedIdentityClientId = "plan-client-id"
                ApplyManagedIdentityClientId = "apply-client-id"
                TerraformStateStorageAccountName = "testterraformstate"
            }

            # Act
            $result = Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $environmentConfig

            # Assert
            $result | Should -Be $true
            Test-Path $configPath | Should -Be $true
            
            # Verify content
            $content = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $content.schemaVersion | Should -Be "1.0"
            $content.environments | Should -Not -BeNullOrEmpty
            $content.environments.$environmentName | Should -Not -BeNullOrEmpty
            $content.environments.$environmentName.EnvironmentName | Should -Be $environmentName
            $content.environments.$environmentName.ResourceGroupName | Should -Be "rg-test"
            $content.environments.$environmentName.Timestamp | Should -Not -BeNullOrEmpty
        }
    }

    Context "Updating an existing configuration file" {
        It "Should update an existing environment in the config file" {
            # Arrange
            $configPath = Join-Path $TestDrive "test-update.jsonc"
            $environmentName = "dev"
            
            # Create initial config
            $initialConfig = [PSCustomObject]@{
                EnvironmentName = $environmentName
                ResourceGroupName = "rg-initial"
                Location = "westus"
            }
            
            # Add initial config
            Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $initialConfig | Out-Null
            
            # Updated config
            $updatedConfig = [PSCustomObject]@{
                EnvironmentName = $environmentName
                ResourceGroupName = "rg-updated"
                Location = "eastus"
            }
            
            # Act
            $result = Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $updatedConfig
            
            # Assert
            $result | Should -Be $true
            
            # Verify content was updated
            $content = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $content.environments.$environmentName.ResourceGroupName | Should -Be "rg-updated"
            $content.environments.$environmentName.Location | Should -Be "eastus"
        }
        
        It "Should add a new environment to an existing config file" {
            # Arrange
            $configPath = Join-Path $TestDrive "test-add-env.jsonc"
            
            # Create initial config with one environment
            $initialConfig = [PSCustomObject]@{
                EnvironmentName = "dev"
                ResourceGroupName = "rg-dev"
            }
            
            # Add initial config
            Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $initialConfig | Out-Null
            
            # New environment config
            $newEnvConfig = [PSCustomObject]@{
                EnvironmentName = "prod"
                ResourceGroupName = "rg-prod"
            }
            
            # Act
            $result = Add-AzBootstrapConfig -ConfigPath $configPath -EnvironmentConfig $newEnvConfig
            
            # Assert
            $result | Should -Be $true
            
            # Verify both environments exist
            $content = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $content.environments.dev | Should -Not -BeNullOrEmpty
            $content.environments.prod | Should -Not -BeNullOrEmpty
            $content.environments.dev.ResourceGroupName | Should -Be "rg-dev"
            $content.environments.prod.ResourceGroupName | Should -Be "rg-prod"
        }
    }
}