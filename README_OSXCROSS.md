
# Cross-building macOS build from Linux

## Installing OSXCross

From [Cross-compiling for macOS from Linux](https://docs.godotengine.org/en/stable/contributing/development/compiling/compiling_for_macos.html#cross-compiling-for-macos-from-linux) on Godot Docs:
> Clone the OSXCross repository somewhere on your machine (or download a ZIP file and extract it somewhere), e.g.:
>
> ```
> git clone --depth=1 https://github.com/tpoechtrager/osxcross.git "$HOME/osxcross"
> ```
> 1. Follow the instructions to package the SDK: https://github.com/tpoechtrager/osxcross#packaging-the-sdk
> 2. Follow the instructions to install OSXCross: https://github.com/tpoechtrager/osxcross#installation

- xcode 15 beta 6 was used when building m8gd

## Installing dependencies

```bash
$ export PATH=$PATH:~/osxcross/target/bin
$ export MACOSX_DEPLOYMENT_TARGET=10.7
$ osxcross-macports install libserialport
```

## Compiling libm8gd

```bash
$ export OSXCROSS_ROOT=~/osxcross
$ scons target=template_release platform=macos arch=x86_64 osxcross_sdk=darwin23
```

## Checking library links

```bash
$ x86_64-apple-darwin23-otool -L project/addons/libm8gd/libm8gd.macos.template_release.framework
```