
# m8-gd: M8 Godot Display

## Description

Provides a 3D scene that is capable of capturing your M8 Tracker's display via m8.run.
Made mostly as a proof-of-concept.

This project makes use of the [spout-gd](https://github.com/you-win/spout-gd) plugin for Godot 4.
Keep in mind that this program only works in Windows since Spout is a Windows-only API.

## Usage

### Prerequisites

- A Windows system
- The [m8.run](https://m8.run) website (recommended to install this site as an app). This can be done with Google Chrome or Microsoft Edge.
- [Open Broadcaster Software (OBS)](https://obsproject.com/)
- [Spout2 Plugin for OBS](https://github.com/Off-World-Live/obs-spout2-plugin)

### Running

At this time there is no EXE of this project to download.
However, you can try to run it through Godot's editor if you wish.

1. Download and extract the source code of this project. (Click the green "Code" button on the top-right > Click "Download ZIP".)
2. Download and extract [Godot 4.3-dev1](https://godotengine.org/download/archive/4.3-dev1/).
3. Open `Godot_v4.1.3-stable_win64.exe`.
4. A project manager should open up. Click the "Import" button, then "Browse", then locate the `project.godot` file of the source code downloaded in Step 1.
5. Click "Import & Edit".
6. Once the project is finished loading, click the play button on the top right to launch m8-gd.

### Setup

In this setup, we will be using an instance of OBS to capture the browser window that m8.run is on.
This instance of OBS will then be a "sender" for Spout, and m8-display will be the "receiver".

1. Open m8.run:
	- Ensure "Snap Pixels" is ON.
	- Resize the m8.run window to around 800x600. The display should be scaled up 2x with some padding.
2. Open OBS:
	- Set the "Base (Canvas) Resolution" to `640x480` (File > Settings > Video).
	- Add a new scene that will be used to capture m8.run.
	- In this scene, add a "Window Capture" source and set it to capture the m8.run browser window.
	- Go to the transform settings of the Window Capture source. (Click on Window Capture under sources and press CTRL+E)
		- Set "Position" to `318.0000 px` and `220.0000 px`.
		- Set "Positional Alignment" to `Center`.
		- Note: At this point, the preview should have mostly the same size and look of the actual M8 screen.
		  Feel free to adjust the position with the arrow keys if it looks misaligned.
	- Go to Tools > Spout Output Settings:
		- Leave the "Spout Output Name" to the default value of "OBS_Spout". This will be the sender name that m8-display expects.
		- Click on "Start". OBS will now be sending video data via Spout.
3. Open m8-gd.
	- Upon opening m8-gd, it will attempt to detect the M8's input device and monitor it through your output device.
	  If needed, disable the audio from m8.run to prevent listening to duplicate audio.
	
Then, the m8-gd window can be streamed and/or recorded with a second instance of OBS or captured with Discord, etc.

## Troubleshooting/Caveats

- If the display in m8-gd is frozen, ensure that both the m8.run and m8-gd windows are visible on your screen.
  They can partially overlap, but they cannot be minimized or completely hidden under another window.
  (OBS can be kept minimized.)

- Keep in mind that in this setup, OBS may crash when trying to change resolutions or the scene while it is sending via Spout.

- If OBS is running, is sending data via Spout, but nothing is shown in m8-gd, try restarting OBS.

## Development

This project has been tested to work on [Godot 4.3-dev1](https://godotengine.org/download/archive/4.3-dev1/),
but should also work on at least [Godot 4.1.3](https://godotengine.org/download/archive/4.1.3-stable/) (the earliest supported version by spout-gd).

If necessary, rebuild the [spout-gd](https://github.com/you-win/spout-gd) plugin according to their instructions.

The 3D scene is contained in `M8Scene.tscn`.
The main scene is `Main.tscn` and displays the 3D scene with additional post processing.

## Screenshots

![screenshot](screenshot.png)

## Assets used

- [M8 Tracker 3D Model by David Junghanns](https://sketchfab.com/3d-models/dirtywave-m8-tracker-05ba530f902e4474b0e01ae2750eec3c)
- [SpoutTexture.gd by erodozer @ GitHub](https://github.com/erodozer/spout-gd/blob/master/SpoutTexture.gd) was adapted for use in this project.
- [Prototype Textures by Kenney](https://kenney-assets.itch.io/prototype-textures)
