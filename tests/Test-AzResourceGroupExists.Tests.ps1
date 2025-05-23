Describe "Test-AzResourceGroupExists" {
    BeforeAll {
        # Load the module and functions
        $modulePath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        . "$modulePath\private\Test-AzResourceGroupExists.ps1"
    }

    Context "When testing Azure resource group existence" {
        It "Should return true when resource group exists" {
            # Arrange
            Mock Invoke-Expression -Verifiable -MockWith { 
                $global:LASTEXITCODE = 0
                return "test-rg" 
            }

            # Act
            $result = Test-AzResourceGroupExists -ResourceGroupName "test-rg"

            # Assert
            $result | Should -BeTrue
            Should -InvokeVerifiable
        }

        It "Should return false when resource group does not exist" {
            # Arrange
            Mock Invoke-Expression -Verifiable -MockWith { 
                $global:LASTEXITCODE = 1
                return $null 
            }

            # Act
            $result = Test-AzResourceGroupExists -ResourceGroupName "nonexistent-rg"

            # Assert
            $result | Should -BeFalse
            Should -InvokeVerifiable
        }

        It "Should return false when an error occurs" {
            # Arrange
            Mock Invoke-Expression -Verifiable -MockWith { throw "Some error" }

            # Act
            $result = Test-AzResourceGroupExists -ResourceGroupName "test-rg"

            # Assert
            $result | Should -BeFalse
            Should -InvokeVerifiable
        }

        It "Should return false when the resource group name doesn't match" {
            # Arrange
            Mock Invoke-Expression -Verifiable -MockWith { 
                $global:LASTEXITCODE = 0
                return "different-rg" 
            }

            # Act
            $result = Test-AzResourceGroupExists -ResourceGroupName "test-rg"

            # Assert
            $result | Should -BeFalse
            Should -InvokeVerifiable
        }
    }
}