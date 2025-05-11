function New-AzBicepDeployment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$EnvironmentName,
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory)]
    [string]$Location, # Used for deployment metadata and as default for resources
    [Parameter(Mandatory)]
    [string]$PlanManagedIdentityName,
    [Parameter(Mandatory)]
    [string]$ApplyManagedIdentityName,
    [Parameter(Mandatory)]
    [string]$GitHubOwner,
    [Parameter(Mandatory)]
    [string]$GitHubRepo,
    [Parameter(Mandatory)]
    [string]$PlanEnvName,
    [Parameter(Mandatory)]
    [string]$ApplyEnvName,
    [Parameter(Mandatory)] # Subscription ID is required for subscription-level deployments
    [string]$ArmSubscriptionId
  )

  $bicepTemplateFile = Join-Path $PSScriptRoot '..' 'templates' 'environment-infra.bicep'
  if (-not (Test-Path $bicepTemplateFile)) {
    throw "Bicep template file not found at '$bicepTemplateFile'."
  }
  $resolvedBicepTemplateFile = Resolve-Path $bicepTemplateFile -ErrorAction Stop

  Write-Host "[az-bootstrap] Deploying Azure infrastructure for '$EnvironmentName' environment via Bicep."
  Write-Host "[az-bootstrap] This may take a few minutes, please wait..."

  $bicepParams = @{
    resourceGroupName          = $ResourceGroupName
    location                   = $Location # Bicep template uses this for RG and MI location
    planManagedIdentityName    = $PlanManagedIdentityName # For the primary/plan MI
    applyManagedIdentityName   = $ApplyManagedIdentityName
    gitHubOwner                = $GitHubOwner.ToLower()
    gitHubRepo                 = $GitHubRepo.ToLower()
    gitHubPlanEnvironmentName  = $PlanEnvName.ToLower()
    gitHubApplyEnvironmentName = $ApplyEnvName.ToLower()
  }
  # Remove any parameters with $null values, as Bicep might error on `paramName=$null`
  $activeBicepParams = $bicepParams.GetEnumerator() | Where-Object { $_.Value -ne $null } | ForEach-Object { "$($_.Name)=$($_.Value)" }

  Write-Verbose "[az-bootstrap] Bicep parameters for subscription deployment: $bicepParamsJson"

  $deploymentName = "AzBootstrap-EnvInfra-${EnvironmentName}-$(Get-Date -Format 'yyyyMMddHHmmssff')"
  
  # Using Start-Process for better stream handling with Azure CLI
  $azCliArgs = @(
    "deployment", "sub", "create",
    "--name", $deploymentName,
    "--location", $Location, # Location for the deployment metadata
    "--template-file", $resolvedBicepTemplateFile.Path,
    "--subscription", $ArmSubscriptionId,
    "--output", "json"
  )
  if ($activeBicepParams.Count -gt 0) {
    $azCliArgs += "--parameters"
    $azCliArgs += $activeBicepParams # Add each KEY=VALUE pair as a separate argument
  }

  Write-Verbose "[az-bootstrap] Executing: az $($azCliArgs -join ' ')"
  $stdoutfile = New-TemporaryFile
  $stderrfile = New-TemporaryFile
  $process = Start-Process "az" -ArgumentList $azCliArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutfile -RedirectStandardError $stderrfile
  $stdout = Get-Content $stdoutfile -Raw
  $stderr = Get-Content $stderrfile -ErrorAction SilentlyContinue
  Remove-Item $stdoutfile, $stderrfile -ErrorAction SilentlyContinue

  if ($process.ExitCode -ne 0) {
    Write-Error "[az-bootstrap] Bicep subscription deployment failed for environment '$EnvironmentName'. Exit Code: $($process.ExitCode)"
    Write-Error "[az-bootstrap] Standard Error: $stderr"
    Write-Error "[az-bootstrap] Standard Output (may contain JSON error from Azure): $stdout"
    throw "Bicep subscription deployment for environment '$EnvironmentName' failed."
  }

  $deploymentOutput = $stdout | ConvertFrom-Json -ErrorAction SilentlyContinue
  if (-not $deploymentOutput -or -not $deploymentOutput.properties -or -not $deploymentOutput.properties.outputs) {
    Write-Error "[az-bootstrap] Bicep deployment outputs not found or failed to parse. Raw STDOUT: $stdout"
    throw "Bicep deployment for environment '$EnvironmentName' did not produce expected outputs."
  }

  $planManagedIdentityClientId = $null
  $applyManagedIdentityClientId = $null

  $planManagedIdentityClientId = $deploymentOutput.properties.outputs.planManagedIdentityClientId.value

  if (-not $planManagedIdentityClientId) {
    throw "Failed to retrieve Primary Managed Identity Client ID from Bicep deployment for environment '$EnvironmentName'."
  }

  $applyManagedIdentityClientId = $deploymentOutput.properties.outputs.applyManagedIdentityClientId.value

  if (-not $applyManagedIdentityClientId) {
    throw "Failed to retrieve Apply-Specific Managed Identity Client ID from Bicep deployment when CreateSeparateApplyMI was true for environment '$EnvironmentName'."
  }
  
  Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
  Write-Host "[az-bootstrap] Bicep deployment for '$EnvironmentName' provisioning state: $($deploymentOutput.properties.provisioningState)."
  Write-Verbose "[az-bootstrap] Plan MI Client ID: $planManagedIdentityClientId"
  Write-Verbose "[az-bootstrap] Apply MI Client ID: $applyManagedIdentityClientId"
  
  return [PSCustomObject]@{
    PlanManagedIdentityClientId  = $planManagedIdentityClientId
    ApplyManagedIdentityClientId = $applyManagedIdentityClientId
  }
}

