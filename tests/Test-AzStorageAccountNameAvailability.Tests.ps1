Describe "Test-AzStorageAccountNameAvailability" {
    BeforeAll { 
        # Import the module
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    # Use InModuleScope to access private functions
    InModuleScope 'az-bootstrap' {
        It "Returns valid=false for empty name" {
            $result = Test-AzStorageAccountNameAvailability -StorageAccountName ""
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Not -BeNullOrEmpty
        }

        It "Returns valid=false for name too short" {
            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "ab"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "between 3 and 24"
        }

        It "Returns valid=false for name too long" {
            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "abcdefghijklmnopqrstuvwxyz"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "between 3 and 24"
        }

        It "Returns valid=false for name with invalid characters" {
            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "invalid-name"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "lowercase letters and numbers"
        }

        It "Returns valid=false for name with uppercase letters" {
            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "InvalidName"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "lowercase letters and numbers"
        }

        It "Calls Azure CLI for valid name format and handles unavailable name" {
            # Mock az command to return that name is not available
            Mock az {
                '{"nameAvailable":false,"reason":"AlreadyExists"}'
            } -ParameterFilter { $args -contains "check-name" }

            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "validnamebutused"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "not available"
            Should -Invoke az -ParameterFilter { $args -contains "check-name" } -Times 1
        }

        It "Returns valid=true for valid and available name" {
            # Mock az command to return that name is available
            Mock az {
                '{"nameAvailable":true,"reason":null}'
            } -ParameterFilter { $args -contains "check-name" }

            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "validandavailable"
            $result.IsValid | Should -Be $true
            Should -Invoke az -ParameterFilter { $args -contains "check-name" } -Times 1
        }

        It "Handles Azure CLI errors" {
            # Mock az command to fail
            Mock az {
                # Set exit code to non-zero to simulate failure
                $global:LASTEXITCODE = 1
                return $null
            } -ParameterFilter { $args -contains "check-name" }

            $result = Test-AzStorageAccountNameAvailability -StorageAccountName "validname"
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Match "Failed to check"
            Should -Invoke az -ParameterFilter { $args -contains "check-name" } -Times 1
            
            # Reset LASTEXITCODE for subsequent tests
            $global:LASTEXITCODE = 0
        }
    }
}