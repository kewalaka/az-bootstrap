Describe "Grant-RBACRole" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls az role assignment create with correct parameters" {
            # Important: Mock in the right order - mock the more specific commands first
            # So they take precedence over general mocks
            
            # Mock the full az command since we're not using ampersand
            Mock az { 
                if ($args -contains 'group' -and $args -contains 'show') {
                    return '{"id":"/subscriptions/0000/resourceGroups/rg-test"}'
                }
                elseif ($args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'list') {
                    return '[]'
                }
                elseif ($args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'create') {
                    return '{"id":"assignment-id"}'
                }
            }
            
            # Set exit code for successful command execution
            $global:LASTEXITCODE = 0
            
            # Execute the function
            { Grant-RBACRole -ResourceGroupName "rg-test" -PrincipalId "principal-id" -RoleDefinitionId "role-id" } | Should -Not -Throw
            
            # Check that az was called with the right parameters
            Assert-MockCalled az -Times 1 -Exactly -Scope It -ParameterFilter { $args -contains 'group' -and $args -contains 'show' }
            Assert-MockCalled az -Times 1 -Exactly -Scope It -ParameterFilter { $args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'list' }
            Assert-MockCalled az -Times 1 -Exactly -Scope It -ParameterFilter { $args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'create' }
        }

        It "Skips creation if role assignment already exists" {
            # Mock the full az command since we're not using ampersand
            Mock az {
                if ($args -contains 'group' -and $args -contains 'show') {
                    return '{"id":"/subscriptions/0000/resourceGroups/rg-test"}'
                }
                elseif ($args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'list') {
                    return '[{"id":"existing-assignment-id"}]' # Return existing assignment
                }
            }
            
            # Set exit code for successful command execution
            $global:LASTEXITCODE = 0
            
            # Execute the function
            { Grant-RBACRole -ResourceGroupName "rg-test" -PrincipalId "principal-id" -RoleDefinitionId "role-id" } | Should -Not -Throw
            
            # Verify role assignment create was NOT called
            Assert-MockCalled az -Times 1 -Exactly -Scope It -ParameterFilter { $args -contains 'group' -and $args -contains 'show' }
            Assert-MockCalled az -Times 1 -Exactly -Scope It -ParameterFilter { $args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'list' }
            Assert-MockCalled az -Times 0 -Exactly -Scope It -ParameterFilter { $args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'create' }
        }

        It "Throws if az group show fails" {
            # Mock the az command to fail for group show
            Mock az {
                if ($args -contains 'group' -and $args -contains 'show') {
                    $global:LASTEXITCODE = 1
                    return $null
                }
            }
            
            # Execute and expect exception
            { Grant-RBACRole -ResourceGroupName "fail-rg" -PrincipalId "principal-id" -RoleDefinitionId "role-id" } | Should -Throw
        }

        It "Throws if az role assignment create fails" {
            # Mock the full az command with role assignment create failing
            Mock az {
                if ($args -contains 'group' -and $args -contains 'show') {
                    $global:LASTEXITCODE = 0
                    return '{"id":"/subscriptions/0000/resourceGroups/rg-test"}'
                }
                elseif ($args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'list') {
                    $global:LASTEXITCODE = 0
                    return '[]' # Return empty array = assignment doesn't exist
                }
                elseif ($args -contains 'role' -and $args -contains 'assignment' -and $args -contains 'create') {
                    $global:LASTEXITCODE = 1
                    return $null
                }
            }
            
            # Execute and expect exception
            { Grant-RBACRole -ResourceGroupName "rg-test" -PrincipalId "principal-id" -RoleDefinitionId "role-id" } | Should -Throw
        }
        
        AfterEach {
            # Reset LASTEXITCODE after each test
            $global:LASTEXITCODE = 0
        }
    }
}
