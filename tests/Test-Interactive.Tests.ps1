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
    
    It "Should handle owner/repo format in target repository name" {
        # Mock Read-Host to simulate user input with owner/repo format
        Mock Read-Host {
            param($prompt)
            
            switch -Wildcard ($prompt) {
                "*Template Repository URL*" { return "https://github.com/test/template-repo" }
                "*Target Repository Name*" { return "myorg/my-repo" }
                "*Azure Location*" { return "westus" }
                "*Resource Group Name*" { return "" } # Accept default
                "*Plan Managed Identity Name*" { return "" } # Accept default
                "*Apply Managed Identity Name*" { return "" } # Accept default
                "*Storage Account Name*" { return "testazb123" }
                "*Proceed*" { return "y" }
                default { return "" }
            }
        }
        
        # Also mock Write-Host to capture the owner/repo detection message
        Mock Write-Host {}
        
        $result = Start-AzBootstrapInteractiveMode -Defaults @{
            InitialEnvironmentName = 'dev';
            TemplateRepoUrl = '';
            TargetRepoName = '';
            Location = 'eastus';
            ResourceGroupName = '';
            PlanManagedIdentityName = '';
            ApplyManagedIdentityName = '';
            TerraformStateStorageAccountName = '';
        }

        # The target repo name should include the full owner/repo
        $result.TargetRepoName | Should -Be "myorg/my-repo"
        
        # But Azure resource names should use only the repo name part
        $result.ResourceGroupName | Should -Be "rg-my-repo-dev"
        
        # Verify Write-Host was called with owner/repo detection message
        Should -Invoke Write-Host -ParameterFilter { $Object -like "*Detected owner/repo format*" }
    }
}