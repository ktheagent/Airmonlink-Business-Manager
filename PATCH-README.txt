Airmonlink Business Manager 1.3.0+8 premium source overlay

Baseline required:
  Airmonlink-Business-Manager-1.1.1-build6-Full-Source.zip

Apply:
  Extract the verified Build 6 full source.
  Copy every file and folder from this patch over the Build 6 project root.
  Replace matching files.
  Do not copy the ZIP itself into the repository.

This patch contains source changes only. It is not a Windows installer.
Run GitHub Actions on feature/build8-commercial-suite before release.
The current pubspec.lock is a Build 6 lockfile; flutter pub get must regenerate it.
