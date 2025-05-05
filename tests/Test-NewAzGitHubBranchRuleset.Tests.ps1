Describe "New-GitHubBranchRuleset" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set branch protection" {
            Mock Invoke-GitHubCliCommand { $null }
            { New-GitHubBranchRuleset -Owner "org" -Repo "repo" -Branch "main" -RequirePR $true -RequiredReviewers 1 } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }
    }
}
