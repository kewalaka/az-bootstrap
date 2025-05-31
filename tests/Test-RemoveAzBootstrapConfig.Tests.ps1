Describe "Remove-AzBootstrapConfig" {
    BeforeAll { 
        # Load the private functions directly for testing
        . "$PSScriptRoot/../private/Remove-AzBootstrapConfig.ps1"
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
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
                }
                prod = [PSCustomObject]@{
                    EnvironmentName = "prod"
                    ResourceGroupName = "rg-test-prod"
                    DeploymentStackName = "azbootstrap-stack-prod-20250521123456"
                }
            }
        }
        $TestConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $TestConfigPath
    }

    It "Removes environment from config file successfully" {
        Mock Write-BootstrapLog { }
        
        $result = Remove-AzBootstrapConfig -EnvironmentName "dev" -ConfigPath $TestConfigPath
        $result | Should -Be $true
        
        # Verify environment was removed
        $updatedConfig = Get-Content -Path $TestConfigPath -Raw | ConvertFrom-Json
        $updatedConfig.environments.PSObject.Properties.Name | Should -Not -Contain "dev"
        $updatedConfig.environments.PSObject.Properties.Name | Should -Contain "prod"
    }

    It "Returns true when environment does not exist" {
        Mock Write-Warning { }
        
        $result = Remove-AzBootstrapConfig -EnvironmentName "nonexistent" -ConfigPath $TestConfigPath
        $result | Should -Be $true
        
        Assert-MockCalled Write-Warning -Exactly 1 -Scope It
    }

    It "Returns true when config file does not exist" {
        Mock Write-Warning { }
        
        $result = Remove-AzBootstrapConfig -EnvironmentName "dev" -ConfigPath "nonexistent.jsonc"
        $result | Should -Be $true
        
        Assert-MockCalled Write-Warning -Exactly 1 -Scope It
    }

    It "Handles missing environments property gracefully" {
        $InvalidConfig = [PSCustomObject]@{
            schemaVersion = "1.0"
        }
        $InvalidConfigPath = Join-Path $TestDrive "invalid-config.jsonc"
        $InvalidConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $InvalidConfigPath
        Mock Write-Warning { }
        
        $result = Remove-AzBootstrapConfig -EnvironmentName "dev" -ConfigPath $InvalidConfigPath
        $result | Should -Be $true
        
        Assert-MockCalled Write-Warning -Exactly 1 -Scope It
    }
}