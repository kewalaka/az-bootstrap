function Install-GitHubCLI {
    $is64bit = [System.Environment]::Is64BitOperatingSystem
    $localPath = Join-Path $PWD ".gh-cli"
    if (-not (Test-Path $localPath)) {
        New-Item -Path $localPath -ItemType Directory -Force | Out-Null
    }
    $releaseApiUrl = "https://api.github.com/repos/cli/cli/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releaseApiUrl -Method Get -ErrorAction Stop
        $assetPattern = $is64bit ? "*linux_amd64.tar.gz" : "*linux_386.tar.gz"
        $asset = $release.assets | Where-Object { $_.name -like $assetPattern } | Select-Object -First 1
        if ($null -eq $asset) {
            Write-Warning "Could not find appropriate GitHub CLI download for your system."
            return $false
        }
        $downloadUrl = $asset.browser_download_url
        $downloadPath = Join-Path $localPath $asset.name
        Write-Host "Downloading GitHub CLI from $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -ErrorAction Stop
        $extractPath = Join-Path $localPath "extracted"
        if (-not (Test-Path $extractPath)) {
            New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        }
        & tar -xzf $downloadPath -C $extractPath
        $ghExe = Get-ChildItem -Path $extractPath -Recurse -Filter "gh" | Select-Object -First 1
        if ($null -eq $ghExe) {
            Write-Warning "Could not find gh binary in the extracted files."
            return $false
        }
        $ghPath = $ghExe.FullName
        & chmod +x $ghPath
        $env:PATH = (Split-Path -Parent $ghPath) + ":$env:PATH"
        try {
            & $ghPath --version | Out-Null
            Write-Host "✅ GitHub CLI successfully installed to $ghPath"
            return $true
        }
        catch {
            Write-Warning "GitHub CLI was downloaded but failed to execute: $_"
            return $false
        }
    }
    catch {
        Write-Warning "Failed to download GitHub CLI: $_"
        return $false
    }
}
