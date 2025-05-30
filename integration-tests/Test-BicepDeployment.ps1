param (
    [switch]$whatif,
    [switch]$deploy
)

function Load-DotEnv {
    param(
        [string]$Path = ".env"
    )
    if (-Not (Test-Path $Path)) {
        throw ".env file not found at $Path. Please create one (see .env.example)."
    }
    $result = @{}
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*#|^\s*$') { return } # skip comments/empty
        if ($_ -match '^(.*?)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            $result[$name] = $value
        }
    }
    return $result
}

# Load environment variables from .env as a hashtable
$scriptpath = if ($PSScriptRoot) { $PSScriptRoot } else { "." }

$bicepParams = Load-DotEnv -Path "$scriptpath/.env"

# Validate required params and remove table header
$activeBicepParams = $bicepParams.GetEnumerator() | Where-Object { $_.Value -ne $null } | ForEach-Object { "$($_.Name)=$($_.Value)" }

if ($whatif) {
    # Example: Run Bicep deployment as a stack (recommended for lifecycle management)
    $deployName = "azb-deploy-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    $whatifCmd = @(
        'az deployment sub create',
        "--name $deployName",
        "--location $($bicepParams.location)",
        "--template-file ../templates/environment-infra.bicep",
        "--what-if",
        "--parameters"
    )
    $whatifCmd += $activeBicepParams
    $whatifCmd = $whatifCmd -join ' '
    Write-Host "Running: $whatifCmd"
    Invoke-Expression $whatifCmd
}

if ($deploy) {
    $stackName = "azb-stack-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    $deploymentCmd = @(
        'stack sub create',
        "--name $stackName",
        "--location $($bicepParams.location)",
        "--template-file ../templates/environment-infra.bicep",
        "--action-on-unmanage deleteResources",
        "--deny-settings-mode none",
        "--parameters"
    )

    $deploymentCmd += $activeBicepParams
    $deploymentCmd = $deploymentCmd -join ' '

    Write-Host "Running: az $deploymentCmd"

    $stdoutfile = New-TemporaryFile
    $stderrfile = New-TemporaryFile
    $process = Start-Process "az" -ArgumentList $deploymentCmd -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutfile -RedirectStandardError $stderrfile
    $stdout = Get-Content $stdoutfile -Raw
    $stderr = Get-Content $stderrfile -ErrorAction SilentlyContinue
    Remove-Item $stdoutfile, $stderrfile -ErrorAction SilentlyContinue

    Write-Host "\nTo delete the stack and all managed resources, run:"
    Write-Host "az stack sub delete --name $stackName --yes --action-on-unmanage deleteResources"
}