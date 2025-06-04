Describe "Test-AzStorageAccountName" {
    BeforeAll {
        # Import the function directly
        . "$PSScriptRoot/../private/Test-AzStorageAccountName.ps1"
    }

    Context "When storage account name format is invalid" {
        BeforeAll {
            # Mock az command for format validation tests (shouldn't be called, but just in case)
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 0
                return '{"nameAvailable":true}'
            }
        }

        It "Should throw error for name with uppercase letters" {
            { Test-AzStorageAccountName -StorageAccountName "TestAccount" } | 
            Should -Throw "Storage account name must be 3-24 lowercase alphanumeric characters."
        }

        It "Should throw error for name with special characters" {
            { Test-AzStorageAccountName -StorageAccountName "test-account" } | 
            Should -Throw "Storage account name must be 3-24 lowercase alphanumeric characters."
        }

        It "Should throw error for name too short" {
            { Test-AzStorageAccountName -StorageAccountName "ab" } | 
            Should -Throw "Storage account name must be 3-24 lowercase alphanumeric characters."
        }

        It "Should throw error for name too long" {
            { Test-AzStorageAccountName -StorageAccountName "abcdefghijklmnopqrstuvwxyz" } | 
            Should -Throw "Storage account name must be 3-24 lowercase alphanumeric characters."
        }
    }

    Context "When Azure CLI fails" {
        BeforeAll {
            # Mock az command to simulate authentication failure
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 1
                return "Please run 'az login' to setup account."
            }
        }

        It "Should provide meaningful error when Azure CLI is not authenticated" {
            { Test-AzStorageAccountName -StorageAccountName "validname123" } |
            Should -Throw "*could not be validated. Azure CLI error: Please run 'az login' to setup account.*"
        }
    }

    Context "When Azure CLI returns invalid JSON" {
        BeforeAll {
            # Mock az command to return invalid JSON
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 0
                return "Invalid JSON response"
            }
        }

        It "Should provide meaningful error when JSON parsing fails" {
            { Test-AzStorageAccountName -StorageAccountName "validname123" } |
            Should -Throw "*could not be validated. Failed to parse Azure CLI response: Invalid JSON response*"
        }
    }

    Context "When storage account name is unavailable" {
        BeforeAll {
            # Mock az command to return name unavailable with reason
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 0
                return '{"nameAvailable":false,"reason":"AlreadyExists","message":"The storage account named validname123 is already taken."}'
            }
        }

        It "Should provide specific reason when name is unavailable" {
            { Test-AzStorageAccountName -StorageAccountName "validname123" } |
            Should -Throw "*is not available: The storage account named validname123 is already taken.*"
        }
    }

    Context "When storage account name is unavailable without message" {
        BeforeAll {
            # Mock az command to return name unavailable without message
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 0
                return '{"nameAvailable":false,"reason":"AlreadyExists"}'
            }
        }

        It "Should provide fallback message when no specific reason is given" {
            { Test-AzStorageAccountName -StorageAccountName "validname123" } |
            Should -Throw "*is not available: Unknown reason*"
        }
    }

    Context "When storage account name is available" {
        BeforeAll {
            # Mock az command to return name available
            Mock -CommandName az -MockWith { 
                $global:LASTEXITCODE = 0
                return '{"nameAvailable":true}'
            }
        }

        It "Should return true when name is available" {
            Test-AzStorageAccountName -StorageAccountName "validname123" | Should -Be $true
        }
    }
}