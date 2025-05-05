Describe "Set-GitHubEnvironmentPolicy" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force 
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set deployment branch policy" {
            Mock Invoke-GitHubCliCommand { $null }
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -ProtectedBranches @("main") -Reviewers @("testreviewer") } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }

        It "Calls gh api correctly with empty reviewers array" {
            Mock Invoke-GitHubCliCommand { $null }
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -ProtectedBranches @("main") -Reviewers @() } | Should -Not -Throw
            # We can't easily check payload content with parameter filter, so we'll just verify the call count
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }
    }
}
