Describe "Invoke-AzGhCommand" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Returns output from gh command" {
            # Mock the gh command to return a successful output
            Mock gh { "Command output" }
            # Mock $LASTEXITCODE to simulate success
            $global:LASTEXITCODE = 0
            
            $output = Invoke-AzGhCommand -Command @("gh", "api", "--method", "GET", "/user")
            $output | Should -Be "Command output"
        }
        
        It "Throws if gh command fails" {
            # Mock gh to throw an error and set exit code to indicate failure
            Mock gh { 
                $global:LASTEXITCODE = 1
                return "Error: API call failed" 
            }
            
            { Invoke-AzGhCommand -Command @("gh", "api", "--method", "GET", "/user") } | Should -Throw
        }
        
        AfterEach {
            # Reset LASTEXITCODE after each test
            $global:LASTEXITCODE = 0
        }
    }
}
