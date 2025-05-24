Describe "Start-AzBootstrapInteractiveMode" {
    BeforeAll {
        # Directly import the function
        . "$PSScriptRoot/../private/Start-AzBootstrapInteractiveMode.ps1"
        
        # Mock Write-Host to avoid output during tests
        Mock Write-Host {}
        
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
        
        $result = Start-AzBootstrapInteractiveMode
        
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
    
    It "Should return null when user cancels" {
        # Mock Read-Host for cancellation
        Mock Read-Host {
            param($prompt)
            
            if ($prompt -match "Proceed") {
                return "n"
            }
            return "test-value"
        }
        
        $result = Start-AzBootstrapInteractiveMode
        $result | Should -BeNullOrEmpty
    }
}