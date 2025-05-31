Describe "Get-AzBootstrapEnvironmentConfig" {
    BeforeAll { 
        # Load the private function directly for testing
        . "$PSScriptRoot/../private/Get-AzBootstrapEnvironmentConfig.ps1"
    }

    BeforeEach {
        $TestConfigPath = Join-Path $TestDrive "test-config.jsonc"
        $TestConfig = [PSCustomObject]@{
            schemaVersion = "1.0"
            environments = [PSCustomObject]@{
                dev = [PSCustomObject]@{
                    EnvironmentName = "dev"
                    ResourceGroupName = "rg-test-dev"
                    DeploymentStackName = "azbootstrap-stack-dev-20250521123456"
                    PlanGitHubEnvironmentName = "dev-iac-plan"
                    ApplyGitHubEnvironmentName = "dev-iac-apply"
                }
                prod = [PSCustomObject]@{
                    EnvironmentName = "prod"
                    ResourceGroupName = "rg-test-prod"
                    DeploymentStackName = "azbootstrap-stack-prod-20250521123456"
                    PlanGitHubEnvironmentName = "prod-iac-plan"
                    ApplyGitHubEnvironmentName = "prod-iac-apply"
                }
            }
        }
        $TestConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $TestConfigPath
    }

    It "Returns environment configuration when environment exists" {
        $result = Get-AzBootstrapEnvironmentConfig -EnvironmentName "dev" -ConfigPath $TestConfigPath
        $result | Should -Not -BeNullOrEmpty
        $result.EnvironmentName | Should -Be "dev"
        $result.ResourceGroupName | Should -Be "rg-test-dev"
    }

    It "Returns null when environment does not exist" {
        $result = Get-AzBootstrapEnvironmentConfig -EnvironmentName "nonexistent" -ConfigPath $TestConfigPath
        $result | Should -BeNullOrEmpty
    }

    It "Returns null when config file does not exist" {
        $result = Get-AzBootstrapEnvironmentConfig -EnvironmentName "dev" -ConfigPath "nonexistent.jsonc"
        $result | Should -BeNullOrEmpty
    }

    It "Handles empty environments object" {
        $EmptyConfig = [PSCustomObject]@{
            schemaVersion = "1.0"
            environments = [PSCustomObject]@{}
        }
        $EmptyConfigPath = Join-Path $TestDrive "empty-config.jsonc"
        $EmptyConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $EmptyConfigPath
        
        $result = Get-AzBootstrapEnvironmentConfig -EnvironmentName "dev" -ConfigPath $EmptyConfigPath
        $result | Should -BeNullOrEmpty
    }
}