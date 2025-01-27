#!/bin/bash

set -e

cd lumina/node-uniffi

./build-android.sh

./build-ios.sh

cd ../../

mkdir -p ./android/src/main/jniLibs/
mkdir -p ./android/src/main/java/tech/

cp -R ./lumina/node-uniffi/app/src/main/jniLibs/ ./android/src/main/jniLibs/
cp -R ./lumina/node-uniffi/app/src/main/java/tech/ ./android/src/main/java/tech/


XCFRAMEWORK_SOURCE="./lumina/node-uniffi/ios/lumina.xcframework/"
IOS_DIR="./ios"

mkdir -p "${IOS_DIR}/Frameworks"
cp -R "${XCFRAMEWORK_SOURCE}" "${IOS_DIR}/Frameworks/lumina.xcframework/"

echo "XCFramework copied and podspec updated! Run 'pod install' in your app's iOS directory."

cp -R ./lumina/node-uniffi/ios/lumina_node.swift ./ios/
cp -R ./lumina/node-uniffi/ios/lumina_node_uniffi.swift ./ios/
