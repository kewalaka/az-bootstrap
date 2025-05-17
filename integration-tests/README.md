# Bicep integration test

This folder exists to help test changes to the Bicep template used for deployment.

To use, populate the `.env` file (see `.env.example` for illustration).

* `bicep-validation.ps1 -whatif` will do a what-if deployment on the resources
* `bicep-validation.ps1 -deploy` will use a deployment stack to deploy resources in `/templates/environment-infra.bicep`.

The `.env` file is used to simulate the process of passing params from Az-Bootstrap,
designed to be similar to the logic in `/private/New-AzBicepDeployment.ps1`

TODO - be good to have this included as part of CI testing.
