fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android test

```sh
[bundle exec] fastlane android test
```

Run Flutter unit and widget tests

### android build

```sh
[bundle exec] fastlane android build
```

Build Flutter release App Bundle (AAB) without uploading

### android build_apk

```sh
[bundle exec] fastlane android build_apk
```

Build Flutter release APK

### android internal

```sh
[bundle exec] fastlane android internal
```

Build and upload AAB to Google Play Internal track with Git archiving

### android closed

```sh
[bundle exec] fastlane android closed
```

Build and upload AAB to Google Play Closed Testing track with Git archiving

### android beta

```sh
[bundle exec] fastlane android beta
```

Build and upload AAB to Google Play Beta track with Git archiving

### android production

```sh
[bundle exec] fastlane android production
```

Build and upload AAB to Google Play Production track with Git archiving

### android promote_to_closed

```sh
[bundle exec] fastlane android promote_to_closed
```

Promote an existing Internal build to Closed testing without rebuilding

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
