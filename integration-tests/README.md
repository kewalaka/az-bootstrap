# Bicep integration test

This folder exists to help test changes to the Bicep template used for deployment.

To use, populate the `.env` file (see `.env.example` for illustration), and then call `bicep-validation.ps1`

This will call the bicep template in `/templates/environment-infra.bicep` in 'what-if' mode.

The `.env` file is used to simulate the process of passing params from Az-Bootstrap,
designed to be similar to the logic in `/private/New-AzBicepDeployment.ps1`

TODO - be good to have this included as part of CI testing.
