Describe "New-GitHubBranchRuleset" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set branch protection" {
            # Mock for GET request to check existing rulesets
            Mock Invoke-GitHubCliCommand -ParameterFilter {
                $Command -contains 'api' -and $Command -contains '/repos/org/repo/rulesets' -and $Command -contains 'GET'
            } -MockWith {
                '[]'  # Return empty array indicating no existing rulesets
            }
            
            # Mock for POST request to create ruleset
            Mock Invoke-GitHubCliCommand -ParameterFilter {
                $Command -contains 'api' -and $Command -contains '/repos/org/repo/rulesets' -and $Command -contains 'POST'
            } -MockWith {
                $null
            }
            
            { New-GitHubBranchRuleset -Owner "org" -Repo "repo" -RulesetName "main" -TargetPattern "main" -RequiredApprovals 1 -DismissStaleReviews $true -RequireCodeOwnerReview $false -RequireLastPushApproval $true -RequireThreadResolution $false -AllowedMergeMethods @("squash") -EnableCopilotReview $true } | Should -Not -Throw
            
            Should -Invoke Invoke-GitHubCliCommand -Exactly 2 -Scope It
        }
    }
}