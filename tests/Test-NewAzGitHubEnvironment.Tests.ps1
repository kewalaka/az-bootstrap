Describe "New-AzGitHubEnvironment" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to create/update environment" {
            Mock Invoke-AzGhCommand { $null }
            { New-AzGitHubEnvironment -Owner "org" -Repo "repo" -EnvironmentName "PLAN" } | Should -Not -Throw
            Assert-MockCalled Invoke-AzGhCommand -Exactly 1 -Scope It
        }
    }
}
