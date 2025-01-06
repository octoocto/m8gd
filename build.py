#!/usr/bin/env python3

import argparse
import os
import platform
import subprocess
import shutil
import shlex
import zipfile
import ssl
import stat
import urllib.request
import urllib.error
import time
from pathlib import Path


BUILD_DIR = "build"
GODOT_VERSION = "4.3"
GODOT_BRANCH = "stable"

################################################################################
# Functions/Variables

godot_url_root = (
    "https://github.com/godotengine/godot/releases/download/{0}-{1}/".format(
        GODOT_VERSION, GODOT_BRANCH
    )
)
godot_zip_export_templates = "Godot_v{0}-{1}.tpz".format(GODOT_VERSION, GODOT_BRANCH)
godot_zip_win = "Godot_v{0}-{1}_win64.exe.zip".format(GODOT_VERSION, GODOT_BRANCH)
godot_zip_linux = "Godot_v{0}-{1}_linux.x86_64.zip".format(GODOT_VERSION, GODOT_BRANCH)
godot_zip_mac = "Godot_v{0}-{1}_macos.universal.zip".format(GODOT_VERSION, GODOT_BRANCH)
godot_path_win = "Godot_v{0}-{1}_win64.exe".format(GODOT_VERSION, GODOT_BRANCH)
godot_path_linux = "Godot_v{0}-{1}_linux.x86_64".format(GODOT_VERSION, GODOT_BRANCH)
godot_path_mac = "Godot.app"

################################################################################
# Argument Parser

parser = argparse.ArgumentParser()

parser.add_argument(
    "--osxcross-sdk",
    type=str,
    default="",
    help="enable building with OSXCross and specify OSXCross SDK",
)
parser.add_argument(
    "--target",
    type=str,
    choices=["debug", "release"],
    default="release",
    help="set building the debug or release version of m8gd",
)
parser.add_argument(
    "--extension-only",
    action="store_true",
    help="only build the gdextension (does not export m8gd)",
)
parser.add_argument(
    "--dev",
    action="store_true",
    help='only build the debug version of the gdextension. an alias for "--extension-only --target=debug"',
)
parser.add_argument(
    "--full",
    action="store_true",
    help="build both the debug and release versions of the gdextension, as well as exporting m8gd",
)
parser.add_argument(
    "--platform",
    type=str,
    choices=["windows", "linux", "macos"],
    default="",
    help="set the target platform to build for",
)

parser.add_argument(
    "--arch",
    type=str,
    default="",
    help="set the target architecture to build for",
)

parser.add_argument(
    "--nodownload",
    action="store_true",
    help="run this script without downloading anything",
)

args = parser.parse_args()

if args.dev:
    args.target = "debug"
    args.extension_only = True


def get_export_templates_path() -> str:
    match platform.system():
        case "Windows":
            return os.path.expandvars("%APPDATA%\\Godot\\export_templates\\4.3.stable")
        case "Linux":
            return os.path.expanduser(
                "~/.local/share/godot/export_templates/4.3.stable"
            )
        case "MacOS":
            return os.path.expanduser(
                "~/Library/Application Support/Godot/export_templates/4.3.stable"
            )
        case _:
            raise EnvironmentError()


def using_cygwin() -> bool:
    return shutil.which("cygpath")


def find_godot() -> str | None:
    path = which("godot")

    if path != None:
        _println(f"found! {path}")
        return path

    if platform.system() == "Windows":
        file_path = Path("%s/%s" % (BUILD_DIR, godot_path_win))
    elif platform.system() == "Linux":
        file_path = Path("%s/%s" % (BUILD_DIR, godot_path_linux))
    elif platform.system() == "Darwin":  # MacOS
        file_path = Path("%s/%s/Contents/MacOS/Godot" % (BUILD_DIR, godot_path_mac))

    if file_path.exists():
        file_path.chmod(file_path.stat().st_mode | stat.S_IEXEC)
        path = which(file_path)
        if path != None:
            return path
        else:
            _println_info(f"Could not find godot in {file_path}!")


def find_command(cmd: str) -> str | None:
    path: str = which(cmd)
    if path != None:
        _println_info(f"Found %s! (%s)" % (cmd, path))
        return path
    else:
        _println_err("Could not find %s!" % cmd)
        quit(1)


def find_bash() -> str | None:
    path: str = shutil.which("bash")
    if path != None:
        _println_info(f"Found bash! (%s)" % path)
        return path
    else:
        _println_err("Could not find bash!")
        quit(1)


def which(path: str) -> str | None:
    if not using_cygwin():
        return shutil.which(path)
    else:
        which_path = shutil.which("which")
        if which_path != None:
            try:
                return subprocess.check_output([which_path, path]).decode().strip()
            except subprocess.CalledProcessError:
                pass


def run(command: str) -> None:
    print(command)
    if not using_cygwin():
        subprocess.run(shlex.split(command), check=True)
    else:
        bash_path = find_bash()
        if bash_path:
            subprocess.run([bash_path, "--login", "-c", command], check=True)


def run_scons(target: str = "", platform: str = "", arch: str = "") -> None:
    scons_target = "target=template_%s" % target if target else ""
    scons_platform = "platform=%s" % platform if platform else ""
    scons_arch = "arch=%s" % arch if arch else ""
    try:
        if args.osxcross_sdk:
            run(
                "scons %s platform=macos arch=x86_64 osxcross_sdk=%s"
                % (scons_target, args.osxcross_sdk)
            )
        else:
            run("scons %s %s %s" % (scons_target, scons_platform, scons_arch))
    except subprocess.CalledProcessError:
        _println_err(
            "Scons was not able to compile the GDExtension successfully. Exiting."
        )
        quit(1)


def _print(text: str) -> None:
    print(f"\033[92m{text}\033[0m", end="")


def _println(text: str) -> None:
    print(f"\033[92m{text}\033[0m")


def _println_info(text: str) -> None:
    print(f"\033[94m{text}\033[0m")


def _println_err(text: str) -> None:
    print(f"\033[91m{text}\033[0m")


################################################################################
# Build Script

target_platform = platform.system().lower() if args.platform == "" else args.platform

godot_target = "--export-{}".format(args.target)

if platform.system() == "Windows":
    os.system("color")

if using_cygwin():
    find_bash()

# create build directory if doesn't exist
Path(BUILD_DIR).mkdir(exist_ok=True)

# git_path = find_command("git")
# run(git_path + " submodule set-branch -b 4.3 thirdparty/godot-cpp")
# run(git_path + " submodule sync")
# run(git_path + " submodule update --init --recursive --remote")

scons_path = find_command("scons")

_println("Compiling libm8gd extension...")
if args.full:
    run_scons("debug", args.platform, args.arch)
    run_scons("release", args.platform, args.arch)
else:
    run_scons(args.target, args.platform, args.arch)

if args.extension_only:
    _println("Done!")
    quit(0)

export_templates_path = get_export_templates_path()
if os.path.exists(export_templates_path):
    _println_info("Found export templates!")
elif not args.nodownload:
    url = godot_url_root + godot_zip_export_templates

    try:
        _print("Downloading export templates from %s..." % url)
        time.sleep(20 / 1000)
        ssl._create_default_https_context = ssl._create_unverified_context
        res = urllib.request.urlretrieve(url)
        _println("done!")
    except urllib.error.URLError as e:
        _println_err("failed! (%s)" % e.reason)
        quit(1)

    # extract .zip
    with zipfile.ZipFile(res[0], "r") as zip:
        zip.extractall(BUILD_DIR)

    # move templates
    shutil.move("%s/templates" % BUILD_DIR, export_templates_path)
else:
    _println_err("Could not find export templates!")
    _println("Download required to continue, but found --nodownload flag. Exiting.")
    quit(1)

godot_path = find_godot()

if godot_path:
    _println_info("Found godot!")
elif not args.nodownload:
    if platform.system() == "Windows":
        url = godot_url_root + godot_zip_win
        path = godot_path_win
    elif platform.system() == "Linux":
        url = godot_url_root + godot_zip_linux
        path = godot_path_linux
    elif platform.system() == "Darwin":
        url = godot_url_root + godot_zip_mac
        path = godot_path_mac

    try:
        _print("Downloading Godot Engine from %s..." % url)
        time.sleep(20 / 1000)
        ssl._create_default_https_context = ssl._create_unverified_context
        res = urllib.request.urlretrieve(url)
        _println("done!")
    except urllib.error.URLError as e:
        _println_err("failed! (%s)" % e.reason)
        quit(1)

    # extract .zip
    with zipfile.ZipFile(res[0], "r") as zip:
        zip.extractall(BUILD_DIR)

    godot_path = find_godot()
else:
    _println_err("Could not find godot!")
    _println("Download required to continue, but found --nodownload flag. Exiting.")
    quit(1)


_println("Exporting Godot project...")
try:
    if platform.system() == "Linux" and args.osxcross_sdk:
        run(
            "%s --headless --path project %s macos ../build/m8gd_macos.zip"
            % (godot_path, godot_target)
        )
    else:
        run(
            "%s --headless --path project %s %s ../build/m8gd_%s.zip"
            % (godot_path, godot_target, target_platform, target_platform)
        )
except subprocess.CalledProcessError:
    _println_err("Godot was not able to export successfully. Exiting.")
    quit(1)

_println('Done! The exported app will be found in the "build" folder.')
quit(0)
