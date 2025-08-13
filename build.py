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

LIBSERIALPORT_PATH = "thirdparty/libserialport/.libs/libserialport.a"
SDL2_PATH = "thirdparty/sdl/build/.libs/libSDL2.a"

BUILD_DIR = "build"
GODOT_VERSION = "4.4"
GODOT_BRANCH = "stable"

################################################################################
# Functions/Variables

godot_url_root = (
    "https://github.com/godotengine/godot/releases/download/{0}-{1}/".format(
        GODOT_VERSION, GODOT_BRANCH
    )
)
godot_zip_export_templates = "Godot_v{0}-{1}_export_templates.tpz".format(
    GODOT_VERSION, GODOT_BRANCH
)
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
    "--host",
    type=str,
    default="",
    help="set C compiler to use to compile libserialport",
)
parser.add_argument(
    "--target",
    type=str,
    choices=["template_debug", "template_release"],
    default="template_release",
    help="set building the debug or release version of m8gd",
)
parser.add_argument(
    "--extension-only",
    action="store_true",
    help="only build the gdextension (does not export m8gd)",
)
parser.add_argument(
    "--export-only",
    action="store_true",
    help="only export m8gd (does not compile the gdextension)",
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
    choices=["windows", "linux", "macos", "all"],
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
    args.target = "template_debug"
    args.extension_only = True


def get_export_templates_path() -> str:
    match platform.system():
        case "Windows":
            return os.path.expandvars(
                f"%APPDATA%\\Godot\\export_templates\\{GODOT_VERSION}.stable"
            )
        case "Linux":
            return os.path.expanduser(
                f"~/.local/share/godot/export_templates/{GODOT_VERSION}.stable"
            )
        case "MacOS" | "Darwin":
            return os.path.expanduser(
                f"~/Library/Application Support/Godot/export_templates/{GODOT_VERSION}.stable"
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


def chmod_x(path: str) -> None:
    file_path = Path(path)
    file_path.chmod(file_path.stat().st_mode | stat.S_IEXEC)


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


def run(command: str, working_directory: str = None) -> None:
    if working_directory:
        cwd = os.getcwd()
        os.chdir(working_directory)

    print(command)
    if not using_cygwin():
        subprocess.run(
            shlex.split(command),
            check=True,
        )
    else:
        bash_path = find_bash()
        if bash_path:
            subprocess.run([bash_path, "--login", "-c", command], check=True)

    if working_directory:
        os.chdir(cwd)


def run_scons(target: str = "", platform: str = "", arch: str = "") -> None:
    scons_target = "target=%s" % target if target else ""
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

if target_platform == "darwin":
    target_platform = "macos"

if args.target == "template_debug":
    godot_target = "--export-debug"
else:
    godot_target = "--export-release"

if platform.system() == "Windows":
    os.system("color")

# create build directory if doesn't exist
Path(BUILD_DIR).mkdir(exist_ok=True)

if not args.export_only:
    make_path = find_command("make")

    # compile libserialport
    if not os.path.exists(LIBSERIALPORT_PATH):
        _println("Compiling libserialport...")

        try:
            chmod_x("thirdparty/libserialport/autogen.sh")
            run("./autogen.sh", "thirdparty/libserialport")
            chmod_x("thirdparty/libserialport/configure")
            if args.host != "":
                run(
                    "./configure --prefix=/usr/{0} --host={0}".format(args.host),
                    "thirdparty/libserialport",
                )
            elif args.arch == "universal":
                run(
                    './configure CFLAGS="-arch arm64 -arch x86_64"',
                    "thirdparty/libserialport",
                )
            else:
                run("./configure", "thirdparty/libserialport")

            if args.arch == "universal":
                run(
                    '%s CFLAGS="-fPIC -arch arm64 -arch x86_64"' % make_path,
                    "thirdparty/libserialport",
                )
            else:
                run("%s CFLAGS=-fPIC" % make_path, "thirdparty/libserialport")
        except subprocess.CalledProcessError:
            _println_err("Errors occured while compiling libserialport. Exiting.")
            quit(1)
    else:
        _println("Found libserialport!")

    # compile sdl2
    if not os.path.exists(SDL2_PATH):
        _println("Compiling sdl2...")

        try:
            chmod_x("thirdparty/sdl/autogen.sh")
            run("./autogen.sh", "thirdparty/sdl")

            chmod_x("thirdparty/sdl/configure")
            configure_args = [
                "--disable-timers",
                "--disable-video",
                "--disable-joystick",
                "--disable-haptic",
            ]
            if args.host != "":
                configure_args.append("--prefix=/usr/%s" % args.host)
                configure_args.append("--host=%s" % args.host)
            elif args.arch == "universal":
                configure_args.append("CFLAGS=\"-arch arm64 -arch x86_64\"")

            run("./configure %s" % " ".join(configure_args), "thirdparty/sdl")

            if args.arch == "universal":
                run(
                    '%s CFLAGS="-fPIC -arch arm64 -arch x86_64"' % make_path,
                    "thirdparty/sdl",
                )
            else:
                run("%s CFLAGS=-fPIC" % make_path, "thirdparty/sdl")
        except subprocess.CalledProcessError:
            _println_err("Errors occured while compiling sdl2. Exiting.")
            quit(1)
    else:
        _println("Found sdl2!")

    # compile gdextension
    scons_path = find_command("scons")
    _println("Compiling libm8gd extension...")

    if args.full:
        run_scons("template_debug", args.platform, args.arch)
        run_scons("template_release", args.platform, args.arch)
    else:
        run_scons(args.target, args.platform, args.arch)

if args.extension_only:
    _println("Done!")
    quit(0)

# find or download export templates
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

# find or download godot
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


def godot_export(godot_path: str, target: str, plat: str) -> bool:
    try:
        if platform.system() == "Linux" and args.osxcross_sdk:
            run(
                "%s --headless --path project %s macos ../build/m8gd_macos.zip"
                % (godot_path, target)
            )
        else:
            run(
                "%s --headless --path project %s %s ../build/m8gd_%s.zip"
                % (godot_path, target, plat, plat)
            )
        return True
    except subprocess.CalledProcessError:
        return False


# export m8gd
_println(f"Exporting Godot project for {target_platform} platform...")

if target_platform == "all":
    for plat in ["windows", "linux", "macos"]:
        _println("Exporting for %s..." % plat)
        if not godot_export(godot_path, godot_target, plat):
            _println_err("Godot was not able to export successfully. Exiting.")
            quit(1)
else:
    if not godot_export(godot_path, godot_target, target_platform):
        _println_err("Godot was not able to export successfully. Exiting.")
        quit(1)

_println('Done! The exported app will be found in the "build" folder.')
quit(0)
