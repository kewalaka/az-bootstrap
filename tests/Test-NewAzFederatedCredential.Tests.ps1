Describe "New-AzFederatedCredential" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls az identity federated-credential create with correct parameters" {
            # Mock az to return success for the command
            Mock az { return '{"name":"fc-test"}' } -ParameterFilter { 
                $args -contains 'identity' -and 
                $args -contains 'federated-credential' -and 
                $args -contains 'create'
            }
            # Mock $LASTEXITCODE to simulate success
            $global:LASTEXITCODE = 0
            
            { New-AzFederatedCredential -ManagedIdentityName "mi-test" -ResourceGroupName "rg-test" -GitHubEnvironmentName "PLAN" -Owner "org" -Repo "repo" } | Should -Not -Throw
            
            Assert-MockCalled az -ParameterFilter { 
                $args -contains 'identity' -and 
                $args -contains 'federated-credential' -and 
                $args -contains 'create'
            } -Exactly 1 -Scope It
        }
        
        It "Throws if az fails" {
            # Mock az to throw an error
            Mock az { 
                $global:LASTEXITCODE = 1
                throw "Command failed: az identity federated-credential create" 
            } -ParameterFilter { 
                $args -contains 'identity' -and 
                $args -contains 'federated-credential' -and 
                $args -contains 'create'
            }
            
            { New-AzFederatedCredential -ManagedIdentityName "fail" -ResourceGroupName "rg-test" -GitHubEnvironmentName "PLAN" -Owner "org" -Repo "repo" } | Should -Throw
        }
        
        AfterEach {
            # Reset LASTEXITCODE after each test
            $global:LASTEXITCODE = 0
        }
    }
}
