Describe "New-GitHubBranchRuleset" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set branch protection" {
            Mock Invoke-GitHubCliCommand {
                param($Command)
                if ($Command -join ' ' -like '*GET*rulesets*') { '[]' } else { $null }
            }
            { New-GitHubBranchRuleset -Owner "org" -Repo "repo" -RulesetName "main" -TargetPattern "main" -RequiredApprovals 1 -DismissStaleReviews $true -RequireCodeOwnerReview $false -RequireLastPushApproval $true -RequireThreadResolution $false -AllowedMergeMethods @("squash") -EnableCopilotReview $true } | Should -Not -Throw
            Assert-MockCalled Invoke-GitHubCliCommand -Exactly 2 -Scope It
        }
    }
}
