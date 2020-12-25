#copy iosbuild to libvpx/build/make (replacing the poriginal file)

eval ./iosbuild.sh --show-build-output --targets "arm64-darwin20-gcc x86_64-darwin18-gcc" --verbose --preserve-build-output

cp libVPX.framework/libVPX libVPX.a

eval xcodebuild -create-xcframework -library libVPX.a -headers libVPX.framework/Headers -output libVPX.xcframework
 
