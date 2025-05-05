function Test-GitHubCLI {
  [CmdletBinding()]
  param()
  try {
    & gh --version | Out-Null
    Write-Verbose "GitHub CLI found in PATH"
  }
  catch {
    Write-Warning "GitHub CLI not found in PATH, please install from https://cli.github.com/"
    return $false
  }

  & gh auth status --hostname github.com | Out-Null
  if ($LASTEXITCODE -ne 0) {
    return $false
  }
  else {
    Write-Verbose "GitHub CLI is authenticated."
    return $true
  }

}

