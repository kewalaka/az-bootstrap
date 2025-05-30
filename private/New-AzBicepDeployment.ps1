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
    [string]$ArmSubscriptionId,
    [string]$TerraformStateStorageAccountName
  )

  $bicepTemplateFile = Join-Path $PSScriptRoot '..' 'templates' 'environment-infra.bicep'
  if (-not (Test-Path $bicepTemplateFile)) {
    throw "Bicep template file not found at '$bicepTemplateFile'."
  }
  $resolvedBicepTemplateFile = Resolve-Path $bicepTemplateFile -ErrorAction Stop
  Write-Bootstraplog "This may take a few minutes, please wait..."

  $bicepParams = @{
    resourceGroupName                = $ResourceGroupName
    location                         = $Location
    planManagedIdentityName          = $PlanManagedIdentityName
    applyManagedIdentityName         = $ApplyManagedIdentityName
    gitHubOwner                      = $GitHubOwner.ToLower()
    gitHubRepo                       = $GitHubRepo.ToLower()
    gitHubPlanEnvironmentName        = $PlanEnvName.ToLower()
    gitHubApplyEnvironmentName       = $ApplyEnvName.ToLower()
    terraformStateStorageAccountName = $TerraformStateStorageAccountName
  }
  # Remove any parameters with $null values, as Bicep might error on `paramName=$null`
  $activeBicepParams = $bicepParams.GetEnumerator() | Where-Object { $_.Value -ne $null } | ForEach-Object { "$( $_.Name )=$( $_.Value )" }

  $stackName = "azbootstrap-stack-$($EnvironmentName)-$(Get-Date -Format 'yyyyMMddHHmmss')"
  $azCliArgs = @(
    'stack', 'sub', 'create',
    '--name', $stackName,
    '--location', $Location,
    '--template-file', $resolvedBicepTemplateFile,
    '--action-on-unmanage', 'deleteResources',
    '--deny-settings-mode', 'none',
    '--parameters'
  )
  $azCliArgs += $activeBicepParams
  Write-Bootstraplog "Creating Azure infrastructure via deployment stack '$stackName'..."
  Write-Verbose "[az-bootstrap] Executing: az $($azCliArgs -join ' ')"
  $stdoutfile = New-TemporaryFile
  $stderrfile = New-TemporaryFile
  $process = Start-Process "az" -ArgumentList $azCliArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutfile -RedirectStandardError $stderrfile
  $stdout = Get-Content $stdoutfile -Raw
  $stderr = Get-Content $stderrfile -ErrorAction SilentlyContinue
  Remove-Item $stdoutfile, $stderrfile -ErrorAction SilentlyContinue

  if ($process.ExitCode -ne 0) {
    Write-Bootstraplog "Stack deployment failed for environment '$EnvironmentName'. Exit Code: $($process.ExitCode)" -Level Error
    Write-Bootstraplog "Standard Error: $stderr" -Level Error
    Write-Bootstraplog "Standard Output (may contain JSON error from Azure): $stdout" -Level Error
    throw "Stack deployment for environment '$EnvironmentName' failed."
  }

  $deploymentOutput = $stdout | ConvertFrom-Json -ErrorAction SilentlyContinue
  if (-not $deploymentOutput -or -not $deploymentOutput.outputs) {
    Write-Error "[az-bootstrap] Stack deployment outputs not found or failed to parse. Raw STDOUT: $stdout"
    throw "Stack deployment for environment '$EnvironmentName' did not produce expected outputs."
  }

  $planManagedIdentityClientId = $null
  $applyManagedIdentityClientId = $null

  $planManagedIdentityClientId = $deploymentOutput.outputs.planManagedIdentityClientId.value

  if (-not $planManagedIdentityClientId) {
    throw "Failed to retrieve Primary Managed Identity Client ID from Bicep deployment for environment '$EnvironmentName'."
  }

  $applyManagedIdentityClientId = $deploymentOutput.outputs.applyManagedIdentityClientId.value

  if (-not $applyManagedIdentityClientId) {
    throw "Failed to retrieve Apply-Specific Managed Identity Client ID from Bicep deployment when CreateSeparateApplyMI was true for environment '$EnvironmentName'."
  }

  $duration = $deploymentOutput.duration
  try {
    $ts = [System.Xml.XmlConvert]::ToTimeSpan($duration)
    $friendlyDuration = "in {0}m {1}s." -f $ts.Minutes, $ts.Seconds
  } catch {
    $friendlyDuration = "."
  }
  
  Write-BootstrapLog "Bicep deployment for '$EnvironmentName' $($deploymentOutput.provisioningState)" $friendlyDuration -Level Success -NoPrefix
  Write-Verbose "[az-bootstrap] Plan MI Client ID: $planManagedIdentityClientId"
  Write-Verbose "[az-bootstrap] Apply MI Client ID: $applyManagedIdentityClientId"

  return [PSCustomObject]@{
    PlanManagedIdentityClientId  = $planManagedIdentityClientId
    ApplyManagedIdentityClientId = $applyManagedIdentityClientId
    DeploymentStackName          = $stackName
  }
}

