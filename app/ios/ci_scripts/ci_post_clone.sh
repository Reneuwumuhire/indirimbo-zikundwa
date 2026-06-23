#!/bin/sh

# Xcode Cloud post-clone step.
#
# Xcode Cloud checks out a clean repo and runs `xcodebuild` directly, but a
# Flutter iOS app depends on generated files that live in the gitignored
# `ios/Flutter/ephemeral/` folder — most importantly the Swift package
# `FlutterGeneratedPluginSwiftPackage`. Those are produced by `flutter pub get`.
#
# So here we install Flutter and run `flutter pub get`, which generates that
# package and writes FLUTTER_ROOT into ios/Flutter/Generated.xcconfig — the later
# xcodebuild "Run Script" phase reads FLUTTER_ROOT from there to find Flutter,
# so we don't need it on PATH for the build step itself.

set -e

FLUTTER_VERSION="3.44.2"
FLUTTER_HOME="$HOME/flutter"

echo "▸ Installing Flutter $FLUTTER_VERSION"
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_HOME"
export PATH="$PATH:$FLUTTER_HOME/bin"

flutter --version
flutter precache --ios

# Ensure native-assets compilation is on (this app compiles SQLite from the
# vendored amalgamation via a build hook). Harmless if already the default.
flutter config --enable-native-assets || true

# The Flutter app lives in app/ at the repo root.
APP_DIR="$CI_PRIMARY_REPOSITORY_PATH/app"

echo "▸ flutter pub get"
cd "$APP_DIR"
flutter pub get

echo "▸ pod install"
cd "$APP_DIR/ios"
pod install

echo "▸ ci_post_clone done"
