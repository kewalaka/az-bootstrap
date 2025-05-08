function Grant-AzRBACRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$PrincipalId,
        [Parameter(Mandatory)]
        [string]$PrincipalName,
        [Parameter(Mandatory)]
        [string]$RoleDefinition
    )

    Write-Host "[az-bootstrap] Assigning role '$RoleDefinition' to principal '$PrincipalName' over resource group '$ResourceGroupName'..."

    # Get the scope of the resource group using Az CLI only
    Write-Verbose "[az-bootstrap] Getting resource group scope for '$ResourceGroupName'..."
    $scope = az group show --name $ResourceGroupName --query id --output tsv
    if ($LASTEXITCODE -ne 0 -or -not $scope) {
        throw "Failed to get resource group scope for '$ResourceGroupName' using Az CLI."
    }
    Write-Verbose "✔ Resource group scope found: $scope"

    # Check if assignment already exists
    $assignment = az role assignment list --assignee $PrincipalId --role $RoleDefinition --scope $scope --query "[0]" | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($assignment) {
        Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
        Write-Host "Role assignment already exists."
        return
    }

    # Create the role assignment
    $cmd = @(
        "az", "role", "assignment", "create",
        "--assignee-object-id", $PrincipalId,
        "--assignee-principal-type", "ServicePrincipal", # Assuming Managed Identity
        "--role", $RoleDefinition,
        "--scope", $scope
    )
    $joined = $cmd -join ' '
    Write-Verbose "[az-bootstrap] Running: $joined"
    & az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal --role $RoleDefinition --scope $scope --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign role '$RoleDefinition' to principal '$PrincipalName ($PrincipalId)' on scope '$scope'."
    }

    Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
    Write-Host "Role '$RoleDefinition' assigned successfully."
}
