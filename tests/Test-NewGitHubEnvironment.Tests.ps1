Describe "New-GitHubEnvironment" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to create/update environment" {
            Mock Invoke-GitHubCliCommand { $null }
            { New-GitHubEnvironment -Owner "org" -Repo "repo" -EnvironmentName "PLAN" } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 1 -Scope It
        }
    }
}
