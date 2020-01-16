set CGO_ENABLED=0
set GOOS=android
set GOARCH=arm64
#set ANDROID_NDK_ROOT=C:\Users\Administrator\AppData\Local\Android\Sdk\ndk\20.1.5948944
#set CC=$ANDROID_NDK_ROOT/arm64/bin/aarch64-linux-android-gcc
#set CXX=$ANDROID_NDK_ROOT/arm64/bin/aarch64-linux-android-g++
#set CGO_LDFLAGS="-g -O2 -llog -lz -L/home/jiangle/goworks/src/p2pudp/p2p_lib_core/dist/Debug/android/ -lp2p_lib_core"
#set CGO_CFLAGS=$CGO_CFLAGS" -DANDROID"
#set CGO_CXXFLAGS=$CGO_CXXFLAGS" -DANDROID"

go build -o ipfs.android 