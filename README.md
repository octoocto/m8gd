
# m8gd: M8 Display and Visualizer

## Description

m8gd renders the M8's display in a 3D environment using the Godot Engine.

This repository consists of the C++ library `libm8gd` that acts as a headless M8 client library and Godot extension, and the Godot project `m8gd` to provide the display.

Still a very early WIP and many features are missing.

## Building from source

### Requirements

- Git
- Python 3.6+
- Scons (`python -m pip install scons`)
- libserialport headers
- [Godot 4.2.2-stable](https://godotengine.org/download/archive/4.2.2-stable/)

If on Windows, a MSYS2/MinGW64 installation is recommended when compiling.

### Building

#### 1. Clone and enter this repo
```bash
$ git clone https://github.com/octoocto/m8gd
$ cd m8gd
$ git submodule update --init
```

#### 2. Compile the GDExtension libm8gd
If necessary, use the `platform=<platform>` flag to specify the platform to compile for.
```sh
$ scons target=template_release

# or, specify a platform ("windows", "linux", or "macos")
$ scons platform=windows target=template_release
```

#### 3. Export the Godot project m8gd
Assuming your Godot editor is named `godot`, run one of these commands to export the program for the desired platform.

```sh
# export to windows
$ godot --headless --path project --export-release windows

# export to linux
$ godot --headless --path project --export-release linux

# export to macos
$ godot --headless --path project --export-release macos
```

A .zip file containing the executable should be created in the `build` folder.

## Development

This project has been tested to work on [Godot 4.2.2-stable](https://godotengine.org/download/archive/4.2.2-stable/).

`libm8gd` source files are located in `src/`.

`m8gd` project and source files are located in `project/`.

## Screenshots

![screenshot](screenshot.png)

## Credits

- Thanks to laamaa for creating [m8c](https://github.com/laamaa/m8c)! This was used as a reference when creating `libm8gd`.
- m8stealth57 and m8stealth89 fonts by Trash80. These fonts were converted to bitmaps.
- [M8 Tracker 3D Model](https://sketchfab.com/3d-models/dirtywave-m8-tracker-05ba530f902e4474b0e01ae2750eec3c) by David Junghanns
- [Prototype Textures](https://kenney-assets.itch.io/prototype-textures) by Kenney
- [Succulent plants model](https://sketchfab.com/3d-models/succulent-plants-ea9a2df2a598410f9f63ba9380795f92) by uniko
