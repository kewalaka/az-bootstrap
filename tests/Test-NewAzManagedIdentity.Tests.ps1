Describe "New-AzManagedIdentity" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls az identity create with correct parameters" {
            Mock az -ParameterFilter { $args -contains 'identity' -and $args -contains 'create' } -MockWith { return '{"name":"mi-test", "principalId":"principal-id", "clientId":"client-id"}' }
            
            $result = New-AzManagedIdentity -ManagedIdentityName "mi-test" -ResourceGroupName "rg-test" -Location "eastus"
            $result.name | Should -Be "mi-test"
            
            Assert-MockCalled az -ParameterFilter { 
                $args -contains 'identity' -and 
                $args -contains 'create' -and 
                $args -contains '--name' -and 
                $args -contains 'mi-test' -and
                $args -contains '--resource-group' -and
                $args -contains 'rg-test' -and
                $args -contains '--location' -and
                $args -contains 'eastus'
            } -Exactly 1 -Scope It
        }
        
        It "Throws if az identity create fails" {
            Mock az -ParameterFilter { $args -contains 'identity' -and $args -contains 'create' } -MockWith { throw "az identity create failed" }
            
            { New-AzManagedIdentity -ManagedIdentityName "fail" -ResourceGroupName "rg-test" -Location "eastus" } | Should -Throw
        }
    }
}
