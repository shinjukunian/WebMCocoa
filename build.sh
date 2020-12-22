./iosbuild.sh --show-build-output --targets "arm64-darwin20-gcc x86_64-darwin16-gcc" --verbose --preserve-build-output

xcodebuild -create-xcframework -framework VPX.framework -output libVPX.framework
 