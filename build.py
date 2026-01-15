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
import itertools
from pathlib import Path

BUILD_DIR = "build"
LIB_DIR = "libm8gd"
LIB_OUT_DIR = "project/addons/libm8gd"
GODOT_VERSION = "4.4.1"
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
    "--target",
    type=str,
    choices=["template_debug", "template_release"],
    default="template_release",
    help="set building the debug or release version of m8gd",
)
parser.add_argument(
    "--extension-only",
    action="store_true",
    help="only build the libm8gd GDExtension (does not export m8gd)",
)
parser.add_argument(
    "--export-only",
    action="store_true",
    help="only export m8gd (does not compile the libm8gd GDExtension)",
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


def run(command: str, working_directory: str = None, env = None, *, capture_output=False):
    if working_directory:
        cwd = os.getcwd()
        os.chdir(working_directory)

    _println_info(command)

    args = []
    result = None
    if not using_cygwin():
        args = shlex.split(command)
    else:
        bash_path = find_bash()
        if bash_path:
            args = [bash_path, "--login", "-c", command]

    result = subprocess.run(args, check=False, env=env, capture_output=capture_output)

    # restore working directory
    if working_directory:
        os.chdir(cwd)

    returncode = -1 if result is None else result.returncode

    if returncode != 0:
        _println_err("Command %s returned non-zero exit status: %d" % (command, returncode))

    return result


def _print(text: str) -> None:
    print(f"\033[92m{text}\033[0m", end="")


def _println(text: str) -> None:
    print(f"\033[92m{text}\033[0m")


def _println_info(text: str) -> None:
    print(f"\033[94m{text}\033[0m", flush=True)


def _println_err(text: str) -> None:
    print(f"\033[91m{text}\033[0m")


################################################################################
# Build Script

if args.extension_only:
    build_extension = True
    build_export = False
elif args.export_only:
    build_extension = False
    build_export = True
else:
    build_extension = True
    build_export = True

target_platform = platform.system().lower() if args.platform == "" else args.platform

match target_platform:
    case "darwin" | "macos":
        target_platform = "macos"
        cargo_targets = ["x86_64-apple-darwin", "aarch64-apple-darwin"]
    case "windows":
        cargo_targets = ["x86_64-pc-windows-gnu"]
    case "linux":
        cargo_targets = ["x86_64-unknown-linux-gnu"]

if args.target == "template_debug":
    godot_target = "--export-debug"
else:
    godot_target = "--export-release"

if platform.system() == "Windows":
    os.system("color")

# create build directory if doesn't exist
build_path = Path(BUILD_DIR)
build_path.mkdir(exist_ok=True)

if build_extension:
    cargo_path = find_command("cargo")
    rustup_path = find_command("rustup")

    cargo_flags = ""
    cargo_target = ""
    if args.target == "template_release":
        cargo_flags += "--release "
        cargo_target = "release"
    else:
        cargo_target = "debug"

    run("%s --version" % cargo_path)
    run("%s --version" % rustup_path)

    for target in cargo_targets:
        if run("%s target add %s" % (rustup_path, target)).returncode != 0:
            quit(1)
        if run("%s build %s --target %s" % (cargo_path, cargo_flags, target), LIB_DIR).returncode != 0:
            quit(1)
        res = run("find %s/target/%s/%s/ -maxdepth 1 -name 'lib*.so' -o -name 'lib*.dylib' -o -name '*.dll'" % (LIB_DIR, target, cargo_target), capture_output=True)

        lib_file = res.stdout.decode().strip().splitlines()[0]
        lib_file_ext = lib_file.split(".")[-1]
        lib_file_out = "%s/%s.%s.%s.%s" % (LIB_OUT_DIR, LIB_DIR, target, cargo_target, lib_file_ext)

        shutil.copy(lib_file, lib_file_out)

    if target_platform == "macos":
        _println_info("Creating universal dylib for macOS...")
        lib_file_x86 = "%s/libm8gd.x86_64-apple-darwin.%s.dylib" % (LIB_OUT_DIR, cargo_target)
        lib_file_arm = "%s/libm8gd.aarch64-apple-darwin.%s.dylib" % (LIB_OUT_DIR, cargo_target)
        lib_file_universal = "%s/libm8gd.universal.%s.dylib" % (LIB_OUT_DIR, cargo_target)
        run("lipo -create %s %s -output %s"
            % (lib_file_x86, lib_file_arm, lib_file_universal))
        run("rm %s %s" % (lib_file_x86, lib_file_arm))

if not build_export:
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
