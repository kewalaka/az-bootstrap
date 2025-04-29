function Grant-RBACRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$PrincipalId,
        [Parameter(Mandatory)]
        [string]$RoleDefinitionId # Can be role name or ID
    )

    Write-Host "[az-bootstrap] Assigning role '$RoleDefinitionId' to principal '$PrincipalId' over resource group '$ResourceGroupName'..."

    # Get the scope of the resource group using Az CLI only
    Write-Host "[az-bootstrap] Getting resource group scope for '$ResourceGroupName'..."
    $scope = az group show --name $ResourceGroupName --query id --output tsv
    if ($LASTEXITCODE -ne 0 -or -not $scope) {
        throw "Failed to get resource group scope for '$ResourceGroupName' using Az CLI."
    }
    Write-Host "✔ Resource group scope found: $scope"

    # Check if assignment already exists
    $assignment = az role assignment list --assignee $PrincipalId --role $RoleDefinitionId --scope $scope --query "[0]" | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($assignment) {
        Write-Host "✔ Role assignment already exists."
        return
    }

    # Create the role assignment
    $cmd = @(
        "az", "role", "assignment", "create",
        "--assignee-object-id", $PrincipalId,
        "--assignee-principal-type", "ServicePrincipal", # Assuming Managed Identity
        "--role", $RoleDefinitionId,
        "--scope", $scope
    )
    $joined = $cmd -join ' '
    Write-Host "[az-bootstrap] Running: $joined"
    $result = & az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal --role $RoleDefinitionId --scope $scope --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign role '$RoleDefinitionId' to principal '$PrincipalId' on scope '$scope'."
    }

    Write-Host "✔ Role '$RoleDefinitionId' assigned successfully."
}
