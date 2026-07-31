# Windows packaging audit

## Identity

- Application: 1.3.0+8
- Setup: `Airmonlink-Business-Manager-1.3.0-Build8-Setup.exe`
- Portable: `Airmonlink-Business-Manager-1.3.0-Build8-Portable.zip`
- Workflow artifact: `Airmonlink-Business-Manager-1.3.0-Build8-Windows`

## Workflow gates

The Windows workflow installs Flutter, runs dependency resolution, formatting, analysis and tests, builds Windows, packages portable and installer artifacts, rejects inherited Build 5/6 release filenames, calculates SHA-256 values and fails when outputs are missing.

## Status

- Workflow source audit: PASS
- Installer source audit: PASS
- Windows compile: MISSING
- Inno Setup compile: MISSING
- Setup install/upgrade: MISSING
- Portable launch: MISSING
- Start Menu/icon verification: MISSING
