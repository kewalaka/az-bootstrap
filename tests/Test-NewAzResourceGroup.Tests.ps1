Describe "New-AzResourceGroup" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls az group create with correct parameters" {
            # Mock 'az group create ...'
            Mock az -ParameterFilter { $args -contains 'group' -and $args -contains 'create' } -MockWith { return '{"name":"rg-test", "location":"eastus"}' }

            $result = New-AzResourceGroup -ResourceGroupName "rg-test" -Location "eastus"
            $result.name | Should -Be "rg-test"

            Assert-MockCalled az -ParameterFilter { $args -contains 'group' -and $args -contains 'create' -and $args -contains '--name' -and $args -contains 'rg-test' -and $args -contains '--location' -and $args -contains 'eastus' } -Exactly 1 -Scope It
        }

        It "Throws if az fails" {
            # Mock 'az group create ...' to fail
            Mock az -ParameterFilter { $args -contains 'group' -and $args -contains 'create' } -MockWith { throw "az group create failed" }

            { New-AzResourceGroup -ResourceGroupName "fail" -Location "eastus" } | Should -Throw
        }
    }
}
