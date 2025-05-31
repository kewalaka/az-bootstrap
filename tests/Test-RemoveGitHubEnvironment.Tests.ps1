Describe "Remove-GitHubEnvironment" {
    BeforeAll { 
        # Load the private functions directly for testing
        . "$PSScriptRoot/../private/Remove-GitHubEnvironment.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubApiCommand.ps1"
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
    }

    It "Calls GitHub API to delete environment" {
        Mock Invoke-GitHubApiCommand { $null }
        Mock Write-BootstrapLog { }
        
        { Remove-GitHubEnvironment -Owner "org" -Repo "repo" -EnvironmentName "test-env" } | Should -Not -Throw
        
        Assert-MockCalled Invoke-GitHubApiCommand -Exactly 1 -Scope It -ParameterFilter {
            $Method -eq "DELETE" -and $Endpoint -eq "/repos/org/repo/environments/test-env"
        }
    }

    It "Handles 404 error gracefully" {
        Mock Invoke-GitHubApiCommand { throw "404 Not Found" }
        Mock Write-BootstrapLog { }
        Mock Write-Warning { }
        
        { Remove-GitHubEnvironment -Owner "org" -Repo "repo" -EnvironmentName "nonexistent-env" } | Should -Not -Throw
        
        Assert-MockCalled Write-Warning -Exactly 1 -Scope It
    }

    It "Throws on other errors" {
        Mock Invoke-GitHubApiCommand { throw "500 Internal Server Error" }
        Mock Write-BootstrapLog { }
        
        { Remove-GitHubEnvironment -Owner "org" -Repo "repo" -EnvironmentName "test-env" } | Should -Throw
    }
}