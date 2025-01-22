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

cp -R ./lumina/node-uniffi/ios/ ./ios/
