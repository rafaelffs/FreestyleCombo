fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios check_builds

```sh
[bundle exec] fastlane ios check_builds
```

List uploaded TestFlight builds and their processing state

### ios setup_internal_testing

```sh
[bundle exec] fastlane ios setup_internal_testing
```

Create an Internal Testing group with access to all builds and add yourself as a tester

### ios clear_export_compliance

```sh
[bundle exec] fastlane ios clear_export_compliance
```

Answer 'no non-exempt encryption' for every build missing export compliance

### ios check_app

```sh
[bundle exec] fastlane ios check_app
```

Check whether the Bundle ID / app record already exist

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Register the Bundle ID and create the App Store Connect app record

### ios setup_signing

```sh
[bundle exec] fastlane ios setup_signing
```

Create a distribution certificate + App Store provisioning profile

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the release IPA

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload the latest build to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
