#copy iosbuild to libvpx/build/make (replacing the poriginal file)
#this file contains changes to how th eautomatic header paths are set

#eval ./iosbuild.sh --show-build-output --targets "arm64-darwin20-gcc x86_64-darwin18-gcc" --verbose --preserve-build-output

eval ./iosbuild.sh --show-build-output --targets "arm64-darwin20-gcc x86_64-darwin20-gcc" --verbose --preserve-build-output --extra-configure-args "--extra-cflags=-mmacosx-version-min=11   --extra-cxxflags=-mmacosx-version-min=11"


cp VPX.framework/libVPX libVPX.a

eval xcodebuild -create-xcframework -library libVPX.a -headers VPX.framework/Headers -output libVPX.xcframework
 
