fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### check

```sh
[bundle exec] fastlane check
```

게이트만 실행 (테스트/검사) — 배포 없음

### beta

```sh
[bundle exec] fastlane beta
```

TestFlight 배포: 게이트 → 빌드번호 +1 → 빌드 → 업로드

### ship

```sh
[bundle exec] fastlane ship
```

App Store 배포: 게이트 → 빌드번호 +1 → 빌드 → 업로드 → 심사 제출

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
