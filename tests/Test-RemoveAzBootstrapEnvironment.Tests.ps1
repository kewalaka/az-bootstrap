Describe "Remove-AzBootstrapEnvironment Integration" {
    BeforeAll { 
        # Load dependencies first
        . "$PSScriptRoot/../private/Get-AzBootstrapEnvironmentConfig.ps1"
        . "$PSScriptRoot/../private/Remove-GitHubEnvironment.ps1"
        . "$PSScriptRoot/../private/Remove-AzDeploymentStack.ps1"
        . "$PSScriptRoot/../private/Remove-AzBootstrapConfig.ps1"
        . "$PSScriptRoot/../private/Get-GitHubRepositoryInfo.ps1"
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubApiCommand.ps1"
        
        # Load main function content without Export-ModuleMember
        $functionContent = Get-Content "$PSScriptRoot/../public/Remove-AzBootstrapEnvironment.ps1" -Raw
        $functionContent = $functionContent -replace 'Export-ModuleMember.*', ''
        Invoke-Expression $functionContent
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
            }
        }
        $TestConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $TestConfigPath
    }

    Context "Core functionality" {
        It "Throws when environment is not found in config" {
            { Remove-AzBootstrapEnvironment -EnvironmentName "nonexistent" -ConfigPath $TestConfigPath -Force } | Should -Throw "*not found in configuration*"
        }

        It "Removes environment with all resources when Force is specified" {
            Mock Get-GitHubRepositoryInfo { 
                return [PSCustomObject]@{ Owner = "testorg"; Repo = "testrepo" }
            }
            Mock Remove-GitHubEnvironment { }
            Mock Remove-AzDeploymentStack { }
            Mock Remove-AzBootstrapConfig { return $true }
            Mock Write-BootstrapLog { }

            { Remove-AzBootstrapEnvironment -EnvironmentName "dev" -ConfigPath $TestConfigPath -GitHubOwner "testorg" -GitHubRepo "testrepo" -Force } | Should -Not -Throw

            Assert-MockCalled Remove-GitHubEnvironment -Exactly 2 -Scope It
            Assert-MockCalled Remove-AzDeploymentStack -Exactly 1 -Scope It
            Assert-MockCalled Remove-AzBootstrapConfig -Exactly 1 -Scope It
        }
    }
}