# Changelog

## v0.5

### Breaking changes

- In order to call non-interactively, `-SkipConfirmation` must be provided

### Added

- Interactive mode.  Call `invoke-azbootstrap` without params for a guided bootstrap.
- Add `.azboostrap.jsonc` to the target repo so Az Bootstrap is aware of configuration on subsequent runs, and to aid with cleanup.
- Preferences file - Favourite templates and default location stored in user profile (`~/.azbootstrap-global.jsonc`)
