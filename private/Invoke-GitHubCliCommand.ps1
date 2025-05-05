function Invoke-GitHubCliCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Command
    )
    $joined = $Command -join ' '
    Write-Verbose "[az-bootstrap] Running: $joined"
    $result = & $Command[0] $Command[1..($Command.Count - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI command failed: $joined"
    }
    return $result
}