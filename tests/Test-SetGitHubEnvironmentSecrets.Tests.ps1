Describe "Set-GitHubEnvironmentSecrets" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        BeforeEach {
            $secrets = @{
                "SECRET1" = "value1"
                "SECRET2" = "value2"
            }
        }

        It "Calls gh secret set for each secret" {
            Mock Invoke-GitHubCliCommand { $null }
            { Set-GitHubEnvironmentSecrets -Owner "org" -Repo "repo" -EnvironmentName "PLAN" -Secrets $secrets } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 2 -Scope It # Once for each secret
        }
    }
}
