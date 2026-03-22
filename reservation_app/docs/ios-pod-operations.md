# iOS Pod Operations

## Current policy

This project uses CocoaPods for iOS dependency resolution.

Do not reintroduce Swift Package Manager Firebase dependencies into the Xcode workspace.
`ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` is intentionally ignored.

## Normal setup

Run from the app root:

```sh
cd /Users/sato-daiya/Documents/reservation-app/reservation_app
flutter pub get
cd ios
pod install
cd ..
```

## If `pod install` fails with Firebase / GitHub clone errors

Typical failure:

```sh
[!] Error installing Firebase
error: RPC failed; HTTP 500 curl 22 The requested URL returned error: 500
fatal: expected flush after ref listing
```

This is usually a GitHub-side or network-path issue while CocoaPods is cloning:

- `https://github.com/firebase/firebase-ios-sdk.git`
- sometimes related Google repositories such as `GoogleDataTransport`

## Recovery steps

### 1. Retry once

```sh
cd /Users/sato-daiya/Documents/reservation-app/reservation_app/ios
pod install
```

### 2. If retry still fails, use the local mirror workaround

```sh
git clone --mirror https://github.com/firebase/firebase-ios-sdk.git /tmp/firebase-ios-sdk-mirror.git

cd /Users/sato-daiya/Documents/reservation-app/reservation_app/ios
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=url.file:///tmp/firebase-ios-sdk-mirror.git.insteadof \
GIT_CONFIG_VALUE_0=https://github.com/firebase/firebase-ios-sdk.git \
pod install
```

### 3. If workspace state looks inconsistent

Run from the app root:

```sh
cd /Users/sato-daiya/Documents/reservation-app/reservation_app
flutter clean
rm -rf ios/Pods ios/.symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/CocoaPods
rm -rf ~/Library/Caches/org.swift.swiftpm
flutter pub get
cd ios
pod install
cd ..
```

## What should be committed

Commit:

- `pubspec.lock`
- `ios/Podfile.lock`
- relevant source changes
- `.gitignore` updates

Do not commit:

- `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `ios/Pods`
- `ios/.symlinks`
- `ios/Flutter/Generated.xcconfig`
- `ios/Flutter/ephemeral`

## Firebase config files

Keep these files in the working tree because local iOS / Android builds depend on them:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

Do not remove them from disk as part of pod troubleshooting.

## Branching for upcoming UI work

Recommended branch for the screen modernization work:

```sh
git switch -c feature/modernize-screens
```

Suggested follow-up branches if the work grows:

- `feature/modernize-auth`
- `feature/modernize-admin`
- `feature/modernize-reservations`
