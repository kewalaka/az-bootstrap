Describe "Start-AzBootstrapInteractiveMode" {
    BeforeAll {
        # Directly import the function
        . "$PSScriptRoot/../private/Start-AzBootstrapInteractiveMode.ps1"
        . "$PSScriptRoot/../private/Test-AzStorageAccountName.ps1"
        . "$PSScriptRoot/../private/Get-ManagedIdentityName.ps1"
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
        . "$PSScriptRoot/../private/Get-AzBootstrapConfig.ps1"

        # Mock Write-Host and Test-AzStorageAccountName
        Mock Write-Host {}
        Mock Test-AzStorageAccountName { $true }
        
        # Mock Get-Random to return consistent results for tests
        Mock Get-Random { return 123 }
    }

    It "Should process interactive inputs correctly" {
        # Mock Get-AzBootstrapConfig to return empty config for consistent test behavior
        Mock Get-AzBootstrapConfig {
            return @{}
        }

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
        }

        # Validate result structure
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain "TemplateRepoUrl"
        $result.Keys | Should -Contain "TargetRepoName"
        $result.Keys | Should -Contain "Location"
        
        # Validate CAF-aligned naming convention defaults
        $result.ResourceGroupName | Should -Be "rgdev" 
        $result.PlanManagedIdentityName | Should -Be "mitest-repodev-plan"
        $result.ApplyManagedIdentityName | Should -Be "mitest-repodev-apply"
    }

    It "Should use defaultRepository from global config when user presses Enter" {
        # Mock Get-AzBootstrapConfig to return a defaultRepository setting
        Mock Get-AzBootstrapConfig {
            return @{
                defaultRepository = "my-org/custom-template"
            }
        }

        # Mock Read-Host to simulate user pressing Enter for template repo (accepting default)
        Mock Read-Host {
            param($prompt)
            
            switch -Wildcard ($prompt) {
                "*Template Repository URL*" { return "" } # Accept default from config
                "*Target Repository Name*" { return "test-repo" }
                "*Azure Location*" { return "westus" }
                "*Resource Group Name*" { return "" } # Accept default
                "*Plan Managed Identity Name*" { return "" } # Accept default
                "*Apply Managed Identity Name*" { return "" } # Accept default
                "*Storage Account Name*" { return "testazb123" }
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
        }

        # Validate that the template repo URL from config was used
        $result.TemplateRepoUrl | Should -Be "my-org/custom-template"
    }

    It "Should fallback to hardcoded default when no defaultRepository in global config" {
        # Mock Get-AzBootstrapConfig to return empty config (no defaultRepository)
        Mock Get-AzBootstrapConfig {
            return @{}
        }

        # Mock Read-Host to simulate user pressing Enter for template repo (accepting default)
        Mock Read-Host {
            param($prompt)
            
            switch -Wildcard ($prompt) {
                "*Template Repository URL*" { return "" } # Accept default
                "*Target Repository Name*" { return "test-repo" }
                "*Azure Location*" { return "westus" }
                "*Resource Group Name*" { return "" } # Accept default
                "*Plan Managed Identity Name*" { return "" } # Accept default
                "*Apply Managed Identity Name*" { return "" } # Accept default
                "*Storage Account Name*" { return "testazb123" }
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
        }

        # Validate that the hardcoded default was used
        $result.TemplateRepoUrl | Should -Be "kewalaka/terraform-azure-starter-template"
    }
}