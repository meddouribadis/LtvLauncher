# Building Arc Launcher

## Prerequisites

- [FVM](https://fvm.app) installed
- Flutter version : **3.29.3** (see `.fvmrc`)

All commands below use `fvm flutter` to ensure the correct Flutter version.

## Install Dependencies

```bash
fvm flutter pub get
```

## Build Flavors

The project supports two flavors:

| Flavor   | Purpose                        | Package suffix |
|----------|--------------------------------|----------------|
| `github` | GitHub releases, sideloading   | `github`       |
| `play`   | Google Play Store distribution  | `play`         |

## Build Commands

### Debug APK

```bash
fvm flutter build apk --debug --flavor github
```

### Release App Bundle

```bash
# GitHub flavor (for GitHub releases / sideloading)
fvm flutter build appbundle --release --flavor github \
  --build-number=<number> --build-name=<version>

# Play flavor (for Google Play Store)
fvm flutter build appbundle --release --flavor play \
  --build-number=<number> --build-name=<version>
```

## Output Paths

| Artifact                        | Path                                                  |
|---------------------------------|-------------------------------------------------------|
| Debug APK                       | `build/app/outputs/flutter-apk/app-github-debug.apk`  |
| GitHub Release AAB              | `build/app/outputs/bundle/githubRelease/app-github-release.aab` |
| Play Release AAB                | `build/app/outputs/bundle/playRelease/app-play-release.aab` |
