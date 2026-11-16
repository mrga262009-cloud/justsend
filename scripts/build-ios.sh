#!/usr/bin/env bash
# Build the Rust static libraries for iOS and package an unsigned IPA.
# Runs locally on macOS and inside the GitHub Actions macos runner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> [1/5] Install Rust iOS targets"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

echo "==> [2/5] Build Rust static library (device)"
CARGO_BUILD_JOBS=2 cargo build --release --manifest-path RustCore/Cargo.toml \
  -p justsend-ffi --target aarch64-apple-ios
mkdir -p App/Libraries/iphoneos
cp RustCore/target/aarch64-apple-ios/release/libjustsend.a App/Libraries/iphoneos/

echo "==> [3/5] Build Rust static library (simulator, universal)"
CARGO_BUILD_JOBS=2 cargo build --release --manifest-path RustCore/Cargo.toml \
  -p justsend-ffi --target aarch64-apple-ios-sim
CARGO_BUILD_JOBS=2 cargo build --release --manifest-path RustCore/Cargo.toml \
  -p justsend-ffi --target x86_64-apple-ios
mkdir -p App/Libraries/iphonesimulator
lipo -create \
  RustCore/target/aarch64-apple-ios-sim/release/libjustsend.a \
  RustCore/target/x86_64-apple-ios/release/libjustsend.a \
  -output App/Libraries/iphonesimulator/libjustsend.a

echo "==> [4/5] Generate Swift bridging header"
if command -v cbindgen >/dev/null 2>&1; then
  (cd RustCore && cbindgen --config cbindgen.toml --crate justsend-ffi \
     --output "$ROOT/App/JustSend-Bridging-Header.h")
else
  echo "cbindgen not found; using committed header"
fi

echo "==> [5/5] Generate Xcode project & build unsigned IPA"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen generate --spec project.yml

DERIVED="$ROOT/build"
rm -rf "$DERIVED"
xcodebuild -project JustSend.xcodeproj \
  -scheme JustSend \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -quiet build

APP="$DERIVED/Build/Products/Release-iphoneos/JustSend.app"
OUT="$ROOT/out"
mkdir -p "$OUT"
rm -rf "$OUT/Payload" "$OUT/JustSend-unsigned.ipa"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
(cd "$OUT" && zip -qry JustSend-unsigned.ipa Payload)
echo "==> DONE: $OUT/JustSend-unsigned.ipa"
ls -lh "$OUT/JustSend-unsigned.ipa"
