
# m8gd: M8 Display and Visualizer

## Description

m8gd renders the M8's display in a 3D environment using the Godot Engine.

This repository consists of the C++ library `libm8gd` that acts as a headless M8 client library and Godot extension, and the Godot project `m8gd` to provide the display.

Still a very early WIP and many features are missing.

## Building from source

### Requirements

- Git
- GCC
- Python 3.6+
- Scons (`python -m pip install scons`)
- pkg-config
- libserialport headers
- [Godot 4.2.2-stable](https://godotengine.org/download/archive/4.2.2-stable/)
- a desktop environment

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

#### 3. Download and Install the export templates for Godot

##### A. Download and Installing with the Godot Editor UI

Run `godot` to open the Project Manager UI.

Click the "Import" button at the top-left of the window, select the project file located in `project/project.godot`, then click "Open" to open the editor.

In the editor, click "Editor" at the top of the window then "Manage Export Templates..." to open the Export Template Manager.

Click "Download and Install" to install the export templates. After it is finished, you can close Export Template Manager and the editor.

##### B. Download and Installing manually

Download the export templates from [here](https://github.com/godotengine/godot-builds/releases/download/4.2.2-stable/Godot_v4.2.2-stable_export_templates.tpz). This is a `.tpz` file which is just a renamed `.zip` file.

Extract the `.tpz` file to get a folder named `templates`. This folder should be renamed to `4.2.2.stable`.

Move the `4.2.2.stable` folder into one of these paths depending on platform:
- Windows: `%APPDATA%\Godot\export_templates\`
- Linux: `~/.local/share/godot/export_templates/`
- MacOS: `~/Library/Application Support/Godot/export_templates/`

#### 4. Export the Godot project m8gd

Assuming your Godot editor is named `godot`, run one of these commands to export the app for the desired platform.

```sh
# export to windows
$ godot --headless --path project --export-release windows ../build/m8gd.zip

# export to linux
$ godot --headless --path project --export-release linux ../build/m8gd.zip

# export to macos
$ godot --headless --path project --export-release macos ../build/m8gd.zip
```

Note: You may see some error messages during the export. This is normal, and the app will still export.

A .zip file containing the app should be created in the `build` folder.

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
- [Asset Drawer](https://github.com/newjoker6/Asset-Drawer) plugin by newjoker6. This is included in this repo when using the editor.