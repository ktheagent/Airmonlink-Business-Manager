# Build the Windows packages on GitHub

## Create the repository

1. Create an empty GitHub repository.
2. Extract the canonical source ZIP on your computer.
3. Open a terminal inside the extracted project.
4. Commit and push the project to the `main` branch.

Example commands after replacing the repository address:

```bash
git init
git add .
git commit -m "Release Airmonlink Business Manager 1.0.0+2"
git branch -M main
git remote add origin YOUR_REPOSITORY_ADDRESS
git push -u origin main
```

## Run the build

1. Open the repository’s **Actions** tab.
2. Select **Validate and Build Windows Release**.
3. Choose **Run workflow** on the `main` branch.
4. Open the completed run.
5. Download `Airmonlink-Business-Manager-1.0.0-build2-Windows` from **Artifacts**.

The downloaded artifact should contain:

```text
Airmonlink-Business-Manager-1.0.0-build2-Windows-Portable.zip
Airmonlink-Business-Manager-1.0.0-build2-Setup.exe
```

## Required successful gates

The workflow must complete source formatting, static analysis, tests, Windows compilation, portable packaging and installer creation. A failed workflow must not be treated as a release.

## Protect the official branch

Configure the `main` branch to require pull requests and the Windows workflow before merging. Do not grant direct write access broadly. Contributors should work through forks and pull requests.
