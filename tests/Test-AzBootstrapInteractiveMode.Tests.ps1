. "$PSScriptRoot/../private/Start-AzBootstrapInteractiveMode.ps1"

Describe "Start-AzBootstrapInteractiveMode" {
    BeforeAll {
        # Mock Read-Host to simulate interactive input
        Mock Read-Host {
            param($prompt)
            
            switch ($prompt) {
                "Enter Template Repository URL" { return "https://github.com/test/template-repo" }
                "Enter Target Repository Name" { return "test-repo" }
                "Enter Azure Location [australiaeast]" { return "westus" }
                "Enter Resource Group Name [azb-rg]" { return "" } # Accept default
                "Enter Plan Managed Identity Name [azb-mi-plan]" { return "" } # Accept default
                "Enter Apply Managed Identity Name [azb-mi-apply]" { return "" } # Accept default
                "Enter Terraform State Storage Account Name [azbstorage]" { return "testazb123" }
                "Proceed with this configuration? (y/N)" { return "y" }
                default { return "" }
            }
        }

        # Mock Write-Host to avoid output during tests
        Mock Write-Host {}
    }

    It "Should return a hashtable with collected values" {
        $result = Start-AzBootstrapInteractiveMode

        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [hashtable]
        
        # Check default values
        $result.TemplateRepoUrl | Should -Be "https://github.com/test/template-repo"
        $result.TargetRepoName | Should -Be "test-repo"
        $result.Location | Should -Be "westus"
        $result.ResourceGroupName | Should -Be "azb-rg" # default
        $result.PlanManagedIdentityName | Should -Be "azb-mi-plan" # default
        $result.ApplyManagedIdentityName | Should -Be "azb-mi-apply" # default
        $result.TerraformStateStorageAccountName | Should -Be "testazb123"
    }

    It "Should return null when user cancels" {
        # Mock Read-Host to simulate cancelling
        Mock Read-Host {
            param($prompt)
            
            if ($prompt -eq "Proceed with this configuration? (y/N)") {
                return "n"
            }
            
            # Return normal values for other prompts
            switch ($prompt) {
                "Enter Template Repository URL" { return "https://github.com/test/template-repo" }
                "Enter Target Repository Name" { return "test-repo" }
                default { return "" }
            }
        }

        $result = Start-AzBootstrapInteractiveMode
        $result | Should -BeNullOrEmpty
    }

    It "Should validate storage account name format" {
        # First try with invalid storage name, then with valid one
        $invalidStorageName = $true
        Mock Read-Host {
            param($prompt)
            
            if ($prompt -eq "Enter Terraform State Storage Account Name [azbstorage]") {
                if ($invalidStorageName) {
                    $invalidStorageName = $false
                    return "INVALID_NAME!"  # Invalid name with uppercase and special chars
                } else {
                    return "validname123"  # Valid name on second attempt
                }
            }
            
            # Return normal values for other prompts
            switch ($prompt) {
                "Enter Template Repository URL" { return "https://github.com/test/template-repo" }
                "Enter Target Repository Name" { return "test-repo" }
                "Proceed with this configuration? (y/N)" { return "y" }
                default { return "" }
            }
        }

        $result = Start-AzBootstrapInteractiveMode
        $result.TerraformStateStorageAccountName | Should -Be "validname123"
    }
}