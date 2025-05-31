Describe "Add-AzBootstrapEnvironment" {
    BeforeAll {
        # Import the module to get all functions
        Import-Module "$PSScriptRoot/../az-bootstrap.psm1" -Force
        
        # Create a temporary directory for test files
        $TestDrive = Join-Path $TestDrive "AzBootstrapEnvironmentTests"
        New-Item -Path $TestDrive -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        # Cleanup
        if (Test-Path $TestDrive) {
            Remove-Item -Path $TestDrive -Recurse -Force
        }
    }

    Context "Non-interactive mode with all parameters" {
        It "Should complete successfully with all required parameters" {
            InModuleScope az-bootstrap {
                # Mock external dependencies
                Mock Test-AzResourceGroupExists { return $false }
                Mock Test-AzStorageAccountName { return $true }
                Mock Get-AzCliContext { 
                    return @{
                        SubscriptionId = "12345678-1234-1234-1234-123456789012"
                        TenantId = "87654321-4321-4321-4321-210987654321"
                    }
                }
                Mock Get-GitHubRepositoryInfo { 
                    return @{
                        Owner = "testowner"
                        Repo = "testrepo"
                    }
                }
                Mock New-AzBicepDeployment { 
                    return @{
                        DeploymentStackName = "azbootstrap-stack-test-20250521123456"
                    }
                }
                Mock New-GitHubEnvironment { }
                Mock Set-GitHubEnvironmentSecrets { }
                Mock Set-GitHubEnvironmentPolicy { }
                Mock Write-BootstrapLog { }
                Mock git { 
                    if ($args -contains "rev-parse") {
                        $global:LASTEXITCODE = 0
                        return "/tmp/test"
                    }
                    $global:LASTEXITCODE = 0
                }

                # Arrange
                $params = @{
                    EnvironmentName = "test"
                    ResourceGroupName = "rg-test-env"
                    Location = "eastus"
                    PlanManagedIdentityName = "mi-test-plan"
                    ApplyManagedIdentityName = "mi-test-apply"
                    SkipConfirmation = $true
                }

                # Act
                $result = Add-AzBootstrapEnvironment @params

                # Assert
                $result | Should -Not -Be $null
                $result.EnvironmentName | Should -Be "test"
                $result.ResourceGroupName | Should -Be "rg-test-env"
                
                # Verify that Azure infrastructure was created
                Assert-MockCalled New-AzBicepDeployment -Times 1
                Assert-MockCalled New-GitHubEnvironment -Times 2  # Plan and Apply environments
            }
        }

        It "Should generate ApplyManagedIdentityName from PlanManagedIdentityName when not provided" {
            InModuleScope az-bootstrap {
                # Mock external dependencies
                Mock Test-AzResourceGroupExists { return $false }
                Mock Test-AzStorageAccountName { return $true }
                Mock Get-AzCliContext { 
                    return @{
                        SubscriptionId = "12345678-1234-1234-1234-123456789012"
                        TenantId = "87654321-4321-4321-4321-210987654321"
                    }
                }
                Mock Get-GitHubRepositoryInfo { 
                    return @{
                        Owner = "testowner"
                        Repo = "testrepo"
                    }
                }
                Mock New-AzBicepDeployment { 
                    return @{
                        DeploymentStackName = "azbootstrap-stack-test-20250521123456"
                    }
                }
                Mock New-GitHubEnvironment { }
                Mock Set-GitHubEnvironmentSecrets { }
                Mock Set-GitHubEnvironmentPolicy { }
                Mock Write-BootstrapLog { }
                Mock git { 
                    if ($args -contains "rev-parse") {
                        $global:LASTEXITCODE = 0
                        return "/tmp/test"
                    }
                    $global:LASTEXITCODE = 0
                }

                # Arrange
                $params = @{
                    EnvironmentName = "test"
                    ResourceGroupName = "rg-test-env"
                    Location = "eastus"
                    PlanManagedIdentityName = "mi-test-env-plan"
                    SkipConfirmation = $true
                }

                # Act
                $result = Add-AzBootstrapEnvironment @params

                # Assert
                Assert-MockCalled New-AzBicepDeployment -ParameterFilter {
                    $ApplyManagedIdentityName -eq "mi-test-env-apply"
                } -Times 1
            }
        }
    }

    Context "SkipConfirmation parameter" {
        It "Should accept SkipConfirmation parameter" {
            InModuleScope az-bootstrap {
                # Mock external dependencies
                Mock Test-AzResourceGroupExists { return $false }
                Mock Test-AzStorageAccountName { return $true }
                Mock Get-AzCliContext { 
                    return @{
                        SubscriptionId = "12345678-1234-1234-1234-123456789012"
                        TenantId = "87654321-4321-4321-4321-210987654321"
                    }
                }
                Mock Get-GitHubRepositoryInfo { 
                    return @{
                        Owner = "testowner"
                        Repo = "testrepo"
                    }
                }
                Mock New-AzBicepDeployment { 
                    return @{
                        DeploymentStackName = "azbootstrap-stack-test-20250521123456"
                    }
                }
                Mock New-GitHubEnvironment { }
                Mock Set-GitHubEnvironmentSecrets { }
                Mock Set-GitHubEnvironmentPolicy { }
                Mock Write-BootstrapLog { }
                Mock git { 
                    if ($args -contains "rev-parse") {
                        $global:LASTEXITCODE = 0
                        return "/tmp/test"
                    }
                    $global:LASTEXITCODE = 0
                }
                
                $params = @{
                    EnvironmentName = "test"
                    ResourceGroupName = "rg-test-env"
                    Location = "eastus"
                    PlanManagedIdentityName = "mi-test-plan"
                    SkipConfirmation = $true
                }

                # Act & Assert - Should not throw
                { Add-AzBootstrapEnvironment @params } | Should -Not -Throw
            }
        }
    }

    Context "Parameter validation" {
        It "Should have EnvironmentName as mandatory parameter" {
            # Get the parameter metadata
            $command = Get-Command Add-AzBootstrapEnvironment
            $envNameParam = $command.Parameters['EnvironmentName']
            
            # Assert
            $envNameParam.Attributes.Mandatory | Should -Contain $true
        }

        It "Should have SkipConfirmation as switch parameter" {
            # Get the parameter metadata
            $command = Get-Command Add-AzBootstrapEnvironment
            $skipConfirmParam = $command.Parameters['SkipConfirmation']
            
            # Assert
            $skipConfirmParam.ParameterType.Name | Should -Be "SwitchParameter"
        }
    }
}