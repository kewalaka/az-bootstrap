Describe "Set-GitHubEnvironmentPolicy" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force 
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set deployment branch policy with user reviewers" {
            Mock Invoke-GitHubCliCommand { $null }
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @("testreviewer") } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }

        It "Calls gh api to set deployment branch policy with no reviewers" {
            Mock Invoke-GitHubCliCommand { $null }
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @() -TeamReviewers @() } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }
    }
}