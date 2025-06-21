Describe "Start-AzBootstrapInteractiveMode" {
    BeforeAll {
        # Directly import the function
        . "$PSScriptRoot/../private/Start-AzBootstrapInteractiveMode.ps1"
        . "$PSScriptRoot/../private/Test-AzStorageAccountName.ps1"
        . "$PSScriptRoot/../private/Get-ManagedIdentityName.ps1"
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"

        # Mock Write-Host and Test-AzStorageAccountName
        Mock Write-Host {}
        Mock Test-AzStorageAccountName { $true }
        
        # Mock Get-Random to return consistent results for tests
        Mock Get-Random { return 123 }
    }

    It "Should process interactive inputs correctly" {
        # Mock Read-Host to simulate user input
        Mock Read-Host {
            param($prompt)
            
            switch -Wildcard ($prompt) {
                "*Template Repository URL*" { return "https://github.com/test/template-repo" }
                "*Target Repository Name*" { return "test-repo" }
                "*Azure Location*" { return "westus" }
                "*Resource Group Name*" { return "" } # Accept default
                "*Plan Managed Identity Name*" { return "" } # Accept default
                "*Apply Managed Identity Name*" { return "" } # Accept default
                "*Storage Account Name*" { return "testazb123" }
                "*Storage Account Firewall Setting*" { return "public" }
                "*Proceed*" { return "y" }
                default { return "" }
            }
        }
        
        $result = Start-AzBootstrapInteractiveMode -Defaults @{
            InitialEnvironmentName = 'dev';
            TemplateRepoUrl = '';
            TargetRepoName = 'my-repo';
            Location = 'eastus';
            ResourceGroupName = 'rgdev';
            PlanManagedIdentityName = 'mitest-repodev-plan';
            ApplyManagedIdentityName = 'mitest-repodev-apply';
            TerraformStateStorageAccountName = 'stdev123';
            StorageAccountFirewall = 'private';
        }

        # Validate result structure
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain "TemplateRepoUrl"
        $result.Keys | Should -Contain "TargetRepoName"
        $result.Keys | Should -Contain "Location"
        $result.Keys | Should -Contain "StorageAccountFirewall"
        
        # Validate CAF-aligned naming convention defaults
        $result.ResourceGroupName | Should -Be "rgdev" 
        $result.PlanManagedIdentityName | Should -Be "mitest-repodev-plan"
        $result.ApplyManagedIdentityName | Should -Be "mitest-repodev-apply"
        $result.StorageAccountFirewall | Should -Be "public"
    }
}